package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.pass.*;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.security.SecretTokenService;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class VaultPassService {
    private final VaultPassRepository passes;
    private final EmployeeRepository employees;
    private final ChamberRepository chambers;
    private final IntakeSessionRepository sessions;
    private final BatchAccessService batchAccess;
    private final AccessService access;
    private final EntityManager entityManager;
    private final SecretTokenService tokens;
    private final CodeImageService codeImages;

    @Transactional
    public IssuedPass issue(AuthPrincipal principal, PassRequest request) {
        access.requireAnyRole(principal, RoleCode.SECURITY, RoleCode.ADMIN);
        LocalDateTime from = utc(request.validFrom());
        LocalDateTime to = utc(request.validTo());
        if (!to.isAfter(from) || !to.isAfter(LocalDateTime.now(ZoneOffset.UTC))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Конец срока должен быть позже начала и текущего времени");
        }
        String code = tokens.generate();
        VaultPass pass = newPass(access.requireStaff(principal), code);
        if (request.employeeId() != null) {
            pass.setEmployee(employees.findById(request.employeeId()).filter(Employee::isActive).orElseThrow(() ->
                    new ResponseStatusException(HttpStatus.NOT_FOUND, "Активный сотрудник не найден")));
        }
        for (Long chamberId : request.chamberIds().stream().sorted().toList()) {
            Chamber chamber = chambers.findByIdForUpdate(chamberId).orElseThrow(() ->
                    new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
            entityManager.refresh(chamber, LockModeType.PESSIMISTIC_WRITE);
            if (chamber.getStatus() != ChamberStatus.ACTIVE) throw conflict("Камера неактивна");
            pass.getChambers().add(chamber);
        }
        pass.setValidFrom(from);
        pass.setValidTo(to);
        pass.setComment(request.comment());
        passes.save(pass);
        return issued(pass, code);
    }

    public PageView<PassView> list(AuthPrincipal principal, int page, int size) {
        access.requireAnyRole(principal, RoleCode.SECURITY, RoleCode.ADMIN);
        var result = passes.findAllByOrderByIdDesc(PageRequest.of(page, size));
        return new PageView<>(result.map(this::view).getContent(), result.getTotalElements(), page, size);
    }

    public PassView get(AuthPrincipal principal, Long id) {
        access.requireAnyRole(principal, RoleCode.SECURITY, RoleCode.ADMIN);
        return view(passes.findById(id).orElseThrow(() -> notFound()));
    }

    @Transactional
    public PassView revoke(AuthPrincipal principal, Long id) {
        access.requireAnyRole(principal, RoleCode.SECURITY, RoleCode.ADMIN);
        VaultPass pass = lock(id);
        if (effectiveStatus(pass) != PassStatus.ACTIVE) throw conflict("Отозвать можно только активный пропуск");
        pass.setStatus(PassStatus.REVOKED);
        pass.setRevokedBy(access.requireStaff(principal));
        pass.setRevokedAt(LocalDateTime.now(ZoneOffset.UTC));
        return view(pass);
    }

    public List<PassView> intakePasses(AuthPrincipal principal, Long sessionId) {
        access.requireRole(principal, RoleCode.CURATOR);
        if (!sessions.existsById(sessionId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Сессия приёма не найдена");
        }
        return passes.findByIntakeSession_IdOrderByIdAsc(sessionId).stream().map(this::view).toList();
    }

    // Вызывается только из IntakeService внутри транзакции, уже заблокировавшей партию.
    @Transactional(propagation = Propagation.MANDATORY)
    public IssuedPass syncIntakePass(IntakeSession session) {
        List<VaultPass> existing = passes.findByIntakeSession_IdOrderByIdAsc(session.getId());
        VaultPass pass;
        String code = null;
        if (existing.isEmpty()) {
            code = tokens.generate();
            pass = newPass(session.getCurator(), code);
            pass.setEmployee(session.getCurator());
            pass.setIntakeSession(session);
            pass.setComment("Приём партии " + session.getBatch().getNumber());
        } else {
            pass = lock(existing.getLast().getId());
            // Перенос приёмки не отменяет решения охраны об отзыве.
            if (pass.getStatus() == PassStatus.REVOKED) return null;
        }
        pass.setValidFrom(session.getPlannedDate().atStartOfDay());
        pass.setValidTo(session.getPlannedDate().plusDays(1).atStartOfDay());
        pass.setStatus(pass.getValidTo().isAfter(LocalDateTime.now(ZoneOffset.UTC))
                ? PassStatus.ACTIVE : PassStatus.EXPIRED);
        pass.getChambers().clear();
        pass.getChambers().add(session.getChamber());
        passes.save(pass);
        return code == null ? null : issued(pass, code);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public VaultPass lockByCode(String code) {
        VaultPass found = passes.findByCodeHash(tokens.hash(code)).orElseThrow(() -> notFound());
        // Тот же порядок, что у приёмки: партия -> пропуск -> камера.
        if (found.getIntakeSession() != null) {
            batchAccess.lock(found.getIntakeSession().getBatch().getId());
        }
        return lock(found.getId());
    }

    private VaultPass lock(Long id) {
        VaultPass pass = passes.findByIdForUpdate(id).orElseThrow(() -> notFound());
        entityManager.refresh(pass, LockModeType.PESSIMISTIC_WRITE);
        return pass;
    }

    private VaultPass newPass(Employee issuer, String code) {
        VaultPass pass = new VaultPass();
        pass.setCodeHash(tokens.hash(code));
        pass.setIssuedBy(issuer);
        return pass;
    }

    public PassStatus effectiveStatus(VaultPass pass) {
        if (pass.getStatus() == PassStatus.ACTIVE && pass.getValidTo() != null
                && !pass.getValidTo().isAfter(LocalDateTime.now(ZoneOffset.UTC))) return PassStatus.EXPIRED;
        return pass.getStatus();
    }

    private PassView view(VaultPass pass) {
        return new PassView(pass.getId(), pass.getEmployee() == null ? null : pass.getEmployee().getId(),
                pass.getIssuedBy().getId(), pass.getIntakeSession() == null ? null : pass.getIntakeSession().getId(),
                effectiveStatus(pass), offset(pass.getValidFrom()), offset(pass.getValidTo()), pass.getComment(),
                pass.getRevokedBy() == null ? null : pass.getRevokedBy().getId(), offset(pass.getRevokedAt()),
                pass.getChambers().stream().map(Chamber::getId).sorted().toList());
    }

    private IssuedPass issued(VaultPass pass, String code) {
        return new IssuedPass(view(pass), code, codeImages.renderQr(code));
    }

    private LocalDateTime utc(OffsetDateTime value) {
        return value.withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime().truncatedTo(ChronoUnit.MICROS);
    }

    private OffsetDateTime offset(LocalDateTime value) {
        return value == null ? null : value.atOffset(ZoneOffset.UTC);
    }

    private ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Пропуск не найден");
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
