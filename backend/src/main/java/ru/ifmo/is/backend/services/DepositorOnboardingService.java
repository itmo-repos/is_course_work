package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.StoredDocument;
import ru.ifmo.is.backend.dto.depositor.ApplicationRequest;
import ru.ifmo.is.backend.dto.depositor.ContractView;
import ru.ifmo.is.backend.dto.depositor.DepositorView;
import ru.ifmo.is.backend.entitiy.Contract;
import ru.ifmo.is.backend.entitiy.Country;
import ru.ifmo.is.backend.entitiy.Depositor;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.enums.ContractStatus;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.ContractRepository;
import ru.ifmo.is.backend.repository.CountryRepository;
import ru.ifmo.is.backend.repository.DepositorRepository;
import ru.ifmo.is.backend.repository.EmployeeRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.io.IOException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DepositorOnboardingService {
    private final BusinessEventService events;
    private static final long MAX_SCAN_BYTES = 15L * 1024 * 1024;

    private final AccessService access;
    private final DepositorAccessService depositorAccess;
    private final DepositorRepository depositorRepository;
    private final ContractRepository contractRepository;
    private final CountryRepository countryRepository;
    private final EmployeeRepository employeeRepository;
    private final PasswordEncoder passwordEncoder;
    private final ContractDocumentService contractDocumentService;
    private final ContractFileStorageService fileStorageService;

    @Transactional
    public DepositorView submitApplication(ApplicationRequest data) {
        String email = data.contactEmail().strip().toLowerCase(Locale.ROOT);
        String legalName = data.legalName().strip();
        String countryCode = data.countryCode().strip().toUpperCase(Locale.ROOT);
        String registrationNumber = data.registrationNumber().strip();

        if (employeeRepository.findByEmailIgnoreCase(email).isPresent()) {
            throw conflict("Аккаунт с таким email уже существует");
        }

        Depositor depositor = depositorRepository.findForUpdateByContactEmailIgnoreCase(email)
                .orElseGet(Depositor::new);
        Long existingId = depositor.getId();
        boolean resubmitted = existingId != null;
        if (resubmitted && (depositor.getStatus() != DepositorStatus.REJECTED
                || !passwordEncoder.matches(data.password(), depositor.getPasswordHash()))) {
            throw conflict("Аккаунт с таким email уже существует");
        }
        if (depositorRepository.findByLegalNameIgnoreCase(legalName)
                .filter(other -> !other.getId().equals(existingId)).isPresent()) {
            throw conflict("Депозитор с таким названием организации уже существует");
        }
        if (depositorRepository.findByCountry_CodeAndRegistrationNumber(countryCode, registrationNumber)
                .filter(other -> !other.getId().equals(existingId)).isPresent()) {
            throw conflict("Депозитор с такими реквизитами уже зарегистрирован");
        }

        Country country = countryRepository.findById(countryCode)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "Неизвестный код страны"));
        depositor.setLegalName(legalName);
        depositor.setCountry(country);
        depositor.setRegistrationNumber(registrationNumber);
        depositor.setLegalAddress(data.legalAddress().strip());
        depositor.setContactPerson(data.contactPerson().strip());
        depositor.setContactPhone(blankToNull(data.contactPhone()));
        if (!resubmitted) {
            depositor.setContactEmail(email);
            depositor.setPasswordHash(passwordEncoder.encode(data.password()));
        }
        depositor.setStatus(DepositorStatus.NEW_REQUEST);
        depositor.setRejectionReason(null);
        try {
            depositorRepository.saveAndFlush(depositor);
        } catch (DataIntegrityViolationException exception) {
            throw conflict("Email, название организации или регистрационные данные уже используются");
        }
        String action = resubmitted ? "APPLICATION_RESUBMITTED" : "APPLICATION_SUBMITTED";
        String description = resubmitted ? "Повторно подана заявка депозитора #" : "Подана заявка депозитора #";
        events.depositor(null, depositor, action, description + depositor.getId());
        return view(depositor);
    }

    @Transactional(readOnly = true)
    public DepositorView getOwnProfile(AuthPrincipal principal) {
        return view(depositorAccess.current(principal));
    }

    @Transactional(readOnly = true)
    public StoredDocument getOwnContract(AuthPrincipal principal) {
        Depositor depositor = depositorAccess.current(principal);
        if (depositor.getStatus() == DepositorStatus.NEW_REQUEST) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Договор ещё не сформирован");
        }
        latestContract(depositor.getId());
        return new StoredDocument(contractDocumentService.readTemplate(), "contract.pdf", "application/pdf");
    }

    @Transactional
    public DepositorView uploadSignedContract(AuthPrincipal principal, MultipartFile upload) {
        Depositor depositor = depositorAccess.lockCurrent(principal);
        boolean retry = depositor.getStatus() == DepositorStatus.CONTRACT_REJECTED;
        if (!retry) requireStatus(depositor, DepositorStatus.AWAITING_CONTRACT);

        Contract contract = latestContract(depositor.getId());
        ContractStatus expectedStatus = retry ? ContractStatus.REJECTED : ContractStatus.GENERATED;
        if (contract.getStatus() != expectedStatus) {
            throw conflict("Договор сейчас не ожидает загрузки подписанного скана");
        }
        UploadedFile file = validateScan(upload);
        String relativePath = "signed/" + contract.getNumber() + "-" + UUID.randomUUID() + "." + file.extension();
        fileStorageService.store(relativePath, file.content());
        cleanUpScansAfterTransaction(relativePath, contract.getSignedScanUri());

        contract.setSignedScanUri(relativePath);
        contract.setSignedUploadedAt(OffsetDateTime.now());
        contract.setStatus(ContractStatus.SCAN_UPLOADED);
        contract.setRejectionReason(null);
        contract.setUpdatedAt(OffsetDateTime.now());
        depositor.setStatus(DepositorStatus.VERIFICATION);
        depositor.setRejectionReason(null);
        events.depositor(principal, depositor, "CONTRACT_SCAN_UPLOADED", retry
                ? "Исправленный скан договора загружен на проверку" : "Скан договора загружен на проверку");
        return view(depositorRepository.save(depositor));
    }

    @Transactional(readOnly = true)
    public List<DepositorView> listApplications(AuthPrincipal principal, DepositorStatus status) {
        access.requireRole(principal, RoleCode.ADMIN);
        List<Depositor> depositors = status == null
                ? depositorRepository.findAll(Sort.by(Sort.Direction.ASC, "createdAt"))
                : depositorRepository.findAllByStatusOrderByCreatedAtAsc(status);
        return depositors.stream().map(this::view).toList();
    }

    @Transactional(readOnly = true)
    public StoredDocument getSignedScan(AuthPrincipal principal, Long depositorId) {
        access.requireRole(principal, RoleCode.ADMIN);
        Contract contract = latestContract(depositorId);
        if (contract.getSignedScanUri() == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Скан подписанного договора не загружен");
        }
        String filename = contract.getSignedScanUri().substring(contract.getSignedScanUri().lastIndexOf('/') + 1);
        String mediaType = filename.endsWith(".pdf") ? "application/pdf"
                : filename.endsWith(".png") ? "image/png" : "image/jpeg";
        return document(contract.getSignedScanUri(), filename, mediaType);
    }

    @Transactional
    public DepositorView approveApplication(AuthPrincipal principal, Long depositorId) {
        access.requireRole(principal, RoleCode.ADMIN);
        Depositor depositor = lockDepositor(depositorId);
        requireStatus(depositor, DepositorStatus.NEW_REQUEST);

        // Keep the rejected agreement and scan as part of the previous submission.
        Contract previous = contractRepository.findFirstByDepositor_IdOrderByGeneratedAtDesc(depositorId).orElse(null);
        Contract contract = previous == null || previous.getStatus() == ContractStatus.REJECTED
                ? newContract(depositor, previous) : previous;
        contract.setStatus(ContractStatus.GENERATED);
        contract.setRejectionReason(null);
        contract.setVerifiedBy(null);
        contract.setVerifiedAt(null);
        contract.setUpdatedAt(OffsetDateTime.now());
        contract.setGeneratedDocUri("classpath:templates/contract.pdf");
        contractRepository.save(contract);

        depositor.setStatus(DepositorStatus.AWAITING_CONTRACT);
        depositor.setRejectionReason(null);
        events.depositor(principal, depositor, "APPLICATION_APPROVED", "Заявка одобрена, договор ожидает подписания");
        return view(depositorRepository.save(depositor));
    }

    @Transactional
    public DepositorView rejectApplication(AuthPrincipal principal, Long depositorId, String reason) {
        access.requireRole(principal, RoleCode.ADMIN);
        Depositor depositor = lockDepositor(depositorId);
        requireStatus(depositor, DepositorStatus.NEW_REQUEST);
        depositor.setStatus(DepositorStatus.REJECTED);
        depositor.setRejectionReason(requiredReason(reason));
        events.depositor(principal, depositor, "APPLICATION_REJECTED", "Заявка отклонена");
        return view(depositorRepository.save(depositor));
    }

    @Transactional
    public DepositorView verifyContract(Long depositorId, AuthPrincipal reviewer) {
        Employee employee = access.requireEmployee(reviewer, RoleCode.ADMIN);
        Depositor depositor = lockDepositor(depositorId);
        requireStatus(depositor, DepositorStatus.VERIFICATION);
        Contract contract = latestContract(depositorId);
        if (contract.getStatus() != ContractStatus.SCAN_UPLOADED) {
            throw conflict("Нет загруженного скана для проверки");
        }
        contract.setStatus(ContractStatus.VERIFIED);
        contract.setVerifiedBy(employee);
        contract.setVerifiedAt(OffsetDateTime.now());
        contract.setRejectionReason(null);
        contract.setUpdatedAt(OffsetDateTime.now());
        contractRepository.save(contract);
        depositor.setStatus(DepositorStatus.ACTIVE);
        depositor.setRejectionReason(null);
        events.depositor(reviewer, depositor, "CONTRACT_VERIFIED", "Договор проверен, депозитор активирован");
        return view(depositorRepository.save(depositor));
    }

    @Transactional
    public DepositorView rejectContract(AuthPrincipal principal, Long depositorId, String reason) {
        access.requireRole(principal, RoleCode.ADMIN);
        Depositor depositor = lockDepositor(depositorId);
        requireStatus(depositor, DepositorStatus.VERIFICATION);
        Contract contract = latestContract(depositorId);
        String rejectionReason = requiredReason(reason);
        contract.setStatus(ContractStatus.REJECTED);
        contract.setRejectionReason(rejectionReason);
        contract.setUpdatedAt(OffsetDateTime.now());
        contractRepository.save(contract);
        depositor.setStatus(DepositorStatus.CONTRACT_REJECTED);
        depositor.setRejectionReason(rejectionReason);
        events.depositor(principal, depositor, "CONTRACT_REJECTED", "Договор отклонён");
        return view(depositorRepository.save(depositor));
    }

    @Transactional
    public DepositorView returnForResubmission(AuthPrincipal principal, Long depositorId) {
        access.requireRole(principal, RoleCode.ADMIN);
        Depositor depositor = lockDepositor(depositorId);
        requireStatus(depositor, DepositorStatus.CONTRACT_REJECTED);
        Contract contract = latestContract(depositorId);
        cleanUpScansAfterTransaction(null, contract.getSignedScanUri());
        contract.setSignedScanUri(null);
        contract.setSignedUploadedAt(null);
        contract.setStatus(ContractStatus.GENERATED);
        contract.setRejectionReason(null);
        contract.setUpdatedAt(OffsetDateTime.now());
        contractRepository.save(contract);
        depositor.setStatus(DepositorStatus.AWAITING_CONTRACT);
        depositor.setRejectionReason(null);
        events.depositor(principal, depositor, "CONTRACT_RETURNED", "Договор возвращён на переподписание");
        return view(depositorRepository.save(depositor));
    }

    @Transactional
    public DepositorView rejectFinally(AuthPrincipal principal, Long depositorId, String reason) {
        access.requireRole(principal, RoleCode.ADMIN);
        Depositor depositor = lockDepositor(depositorId);
        requireStatus(depositor, DepositorStatus.CONTRACT_REJECTED);
        depositor.setStatus(DepositorStatus.REJECTED);
        depositor.setRejectionReason(requiredReason(reason));
        events.depositor(principal, depositor, "APPLICATION_REJECTED_FINALLY", "Заявка окончательно отклонена");
        return view(depositorRepository.save(depositor));
    }

    private void cleanUpScansAfterTransaction(String uploadedScan, String previousScan) {
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                String obsoleteScan = switch (status) {
                    case STATUS_COMMITTED -> previousScan;
                    case STATUS_ROLLED_BACK -> uploadedScan;
                    default -> null;
                };
                if (obsoleteScan == null) return;
                try {
                    fileStorageService.delete(obsoleteScan);
                } catch (RuntimeException exception) {
                    log.warn("Не удалось удалить неиспользуемый скан {}", obsoleteScan, exception);
                }
            }
        });
    }

    private Contract newContract(Depositor depositor, Contract previous) {
        Contract contract = new Contract();
        contract.setDepositor(depositor);
        String prefix = "CNTR-" + LocalDate.now().getYear() + "-";
        contract.setNumber(prefix + (previous == null ? String.format("%06d", depositor.getId()) : "R" + previous.getId()));
        contract.setStatus(ContractStatus.GENERATED);
        contract.setGeneratedAt(OffsetDateTime.now());
        contract.setUpdatedAt(OffsetDateTime.now());
        return contract;
    }

    private Depositor lockDepositor(Long id) {
        return depositorRepository.findByIdForUpdate(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Депозитор не найден"));
    }

    private Contract latestContract(Long depositorId) {
        return contractRepository.findFirstByDepositor_IdOrderByGeneratedAtDesc(depositorId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Договор не найден"));
    }

    private DepositorView view(Depositor depositor) {
        Contract contract = depositor.getStatus() == DepositorStatus.NEW_REQUEST ? null
                : contractRepository.findFirstByDepositor_IdOrderByGeneratedAtDesc(depositor.getId()).orElse(null);
        return new DepositorView(depositor.getId(), depositor.getLegalName(), depositor.getCountry().getCode(),
                depositor.getCountry().getName(), depositor.getRegistrationNumber(), depositor.getLegalAddress(),
                depositor.getContactPerson(), depositor.getContactEmail(), depositor.getContactPhone(),
                depositor.getStatus(), depositor.getRejectionReason(), depositor.getCreatedAt(),
                contract == null ? null : new ContractView(contract.getNumber(), contract.getStatus(),
                        contract.getRejectionReason()));
    }

    private StoredDocument document(String path, String filename, String mediaType) {
        return new StoredDocument(fileStorageService.read(path), filename, mediaType);
    }

    private UploadedFile validateScan(MultipartFile upload) {
        if (upload == null || upload.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Файл скана не передан");
        }
        if (upload.getSize() > MAX_SCAN_BYTES) {
            throw new ResponseStatusException(HttpStatus.CONTENT_TOO_LARGE, "Максимальный размер скана - 15 МБ");
        }
        try {
            byte[] content = upload.getBytes();
            if (startsWith(content, "%PDF-".getBytes())) return new UploadedFile(content, "pdf");
            if (startsWith(content, new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF})) {
                return new UploadedFile(content, "jpg");
            }
            if (startsWith(content, new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A})) {
                return new UploadedFile(content, "png");
            }
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Поддерживаются только PDF, JPEG и PNG");
        } catch (IOException exception) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Не удалось прочитать загруженный файл", exception);
        }
    }

    private static boolean startsWith(byte[] value, byte[] prefix) {
        if (value.length < prefix.length) return false;
        for (int index = 0; index < prefix.length; index++) {
            if (value[index] != prefix[index]) return false;
        }
        return true;
    }

    private static void requireStatus(Depositor depositor, DepositorStatus expected) {
        if (depositor.getStatus() != expected) {
            throw conflict("Операция недоступна для статуса " + depositor.getStatus());
        }
    }

    private static String requiredReason(String reason) {
        if (reason == null || reason.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Укажите причину отклонения");
        }
        return reason.strip();
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.strip();
    }

    private static ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }

    private record UploadedFile(byte[] content, String extension) {}
}
