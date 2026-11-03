package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.storage.StoragePlaceView;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalBoxView;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalRequestView;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalSessionSummary;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalSessionView;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class WithdrawalService {
    private final WithdrawalRequestRepository requests;
    private final WithdrawalSessionRepository sessions;
    private final BatchRepository batches;
    private final BoxRepository boxes;
    private final AccessService access;
    private final ContractRepository contracts;
    private final EntityManager entityManager;

    @Transactional
    public WithdrawalRequestView submit(AuthPrincipal principal, Long batchId, List<Long> boxIds, String reason, LocalDate desiredDate) {
        access.requireDepositor(principal);
        Batch batch = lockBatch(batchId);
        checkOwner(principal, batch.getDepositor().getId());
        if (batch.getDepositor().getStatus() != DepositorStatus.ACTIVE) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Подавать заявку может только активный депозитор");
        }
        if (batch.getStatus() != BatchStatus.PLACED && batch.getStatus() != BatchStatus.PARTIALLY_PLACED) {
            throw conflict("Сначала завершите приём партии");
        }
        if (new HashSet<>(boxIds).size() != boxIds.size()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Коробки в заявке не должны повторяться");
        }
        List<Box> selected = new ArrayList<>();
        for (Long boxId : boxIds) {
            Box box = boxes.findById(boxId).orElseThrow(() -> notFound("Коробка"));
            if (!box.getBatch().getId().equals(batchId)) {
                throw notFound("Коробка");
            }
            requirePlaced(box);
            selected.add(box);
        }
        // Блокировка партии общая с приёмом и перемещением; пересекающиеся заявки создаются последовательно.
        if (requests.hasActiveRequestForBoxes(boxIds)) {
            throw conflict("Одна из коробок уже включена в активную заявку на изъятие");
        }
        WithdrawalRequest request = new WithdrawalRequest();
        request.setDepositor(batch.getDepositor());
        request.setBatch(batch);
        request.setReason(reason.strip());
        request.setDesiredDate(desiredDate);
        request.setBoxes(selected);
        requests.save(request);
        return requestView(request);
    }

    public List<WithdrawalRequestView> ownRequests(AuthPrincipal principal) {
        access.requireDepositor(principal);
        List<WithdrawalRequestView> result = new ArrayList<>();
        for (WithdrawalRequest request : requests.findAllByDepositor_IdOrderBySubmittedAtDesc(principal.id())) {
            result.add(requestView(request));
        }
        return result;
    }

    public WithdrawalRequestView ownRequest(AuthPrincipal principal, Long id) {
        access.requireDepositor(principal);
        WithdrawalRequest request = findRequest(id);
        checkOwner(principal, request.getDepositor().getId());
        return requestView(request);
    }

    public List<WithdrawalRequestView> curatorRequests(AuthPrincipal principal, WithdrawalStatus status) {
        access.requireRole(principal, RoleCode.CURATOR);
        return listRequests(status);
    }

    public WithdrawalRequestView curatorRequest(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.CURATOR);
        return requestView(findRequest(id));
    }

    public List<WithdrawalRequestView> adminRequests(AuthPrincipal principal, WithdrawalStatus status) {
        access.requireRole(principal, RoleCode.ADMIN);
        return listRequests(status);
    }

    public WithdrawalRequestView adminRequest(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.ADMIN);
        return requestView(findRequest(id));
    }

    @Transactional
    public WithdrawalRequestView beginReview(AuthPrincipal principal, Long id) {
        Employee curator = access.requireEmployee(principal, RoleCode.CURATOR);
        WithdrawalRequest request = lockRequest(id);
        requireStatus(request, WithdrawalStatus.SUBMITTED);
        request.setCurator(curator);
        request.setStatus(WithdrawalStatus.CURATOR_REVIEW);
        return requestView(request);
    }

    @Transactional
    public WithdrawalRequestView curatorApprove(AuthPrincipal principal, Long id) {
        Employee curator = access.requireEmployee(principal, RoleCode.CURATOR);
        WithdrawalRequest request = lockRequest(id);
        requireStatus(request, WithdrawalStatus.CURATOR_REVIEW);
        validateForWithdrawal(request);
        request.setCurator(curator);
        request.setCuratorDecisionAt(OffsetDateTime.now());
        request.setStatus(WithdrawalStatus.LEGAL_APPROVAL);
        return requestView(request);
    }

    @Transactional
    public WithdrawalRequestView curatorReject(AuthPrincipal principal, Long id, String reason) {
        Employee curator = access.requireEmployee(principal, RoleCode.CURATOR);
        WithdrawalRequest request = lockRequest(id);
        requireStatus(request, WithdrawalStatus.CURATOR_REVIEW);
        request.setCurator(curator);
        request.setCuratorDecisionAt(OffsetDateTime.now());
        request.setRejectionReason(reason.strip());
        request.setStatus(WithdrawalStatus.REJECTED);
        return requestView(request);
    }

    @Transactional
    public WithdrawalRequestView adminApprove(AuthPrincipal principal, Long id) {
        Employee admin = access.requireEmployee(principal, RoleCode.ADMIN);
        WithdrawalRequest request = lockRequest(id);
        requireStatus(request, WithdrawalStatus.LEGAL_APPROVAL);
        validateForWithdrawal(request);
        request.setAdmin(admin);
        request.setAdminDecisionAt(OffsetDateTime.now());
        request.setStatus(WithdrawalStatus.APPROVED);
        return requestView(request);
    }

    @Transactional
    public WithdrawalRequestView adminReject(AuthPrincipal principal, Long id, String reason) {
        Employee admin = access.requireEmployee(principal, RoleCode.ADMIN);
        WithdrawalRequest request = lockRequest(id);
        requireStatus(request, WithdrawalStatus.LEGAL_APPROVAL);
        request.setAdmin(admin);
        request.setAdminDecisionAt(OffsetDateTime.now());
        request.setRejectionReason(reason.strip());
        request.setStatus(WithdrawalStatus.REJECTED);
        return requestView(request);
    }

    @Transactional
    public WithdrawalSessionView planSession(AuthPrincipal principal, Long requestId, LocalDate plannedDate) {
        Employee curator = access.requireEmployee(principal, RoleCode.CURATOR);
        WithdrawalRequest request = lockRequest(requestId);
        requireStatus(request, WithdrawalStatus.APPROVED);
        validateForWithdrawal(request);
        if (sessions.existsByRequest_Id(requestId)) {
            throw conflict("У заявки уже есть сессия изъятия");
        }
        WithdrawalSession session = new WithdrawalSession();
        session.setRequest(request);
        session.setCurator(curator);
        session.setPlannedDate(plannedDate);
        session.setBoxes(new ArrayList<>(request.getBoxes()));
        sessions.save(session);
        return sessionView(session);
    }

    public WithdrawalSessionView getSession(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.CURATOR);
        return sessionView(findSession(id));
    }

    @Transactional
    public WithdrawalSessionView reschedule(AuthPrincipal principal, Long id, LocalDate plannedDate) {
        access.requireRole(principal, RoleCode.CURATOR);
        WithdrawalSession session = lockSession(id);
        requirePlanned(session);
        requireStatus(session.getRequest(), WithdrawalStatus.APPROVED);
        session.setPlannedDate(plannedDate);
        session.setUpdatedAt(OffsetDateTime.now());
        return sessionView(session);
    }

    @Transactional
    public WithdrawalSessionView complete(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.CURATOR);
        WithdrawalSession session = lockSession(id);
        requirePlanned(session);
        WithdrawalRequest request = session.getRequest();
        requireStatus(request, WithdrawalStatus.APPROVED);
        if (session.getPlannedDate().isAfter(LocalDate.now())) {
            throw conflict("Дата сессии изъятия ещё не наступила");
        }
        validateForWithdrawal(request);
        Set<Long> requestedIds = new HashSet<>();
        for (Box box : request.getBoxes()) requestedIds.add(box.getId());
        Set<Long> sessionIds = new HashSet<>();
        for (Box box : session.getBoxes()) sessionIds.add(box.getId());
        if (!requestedIds.equals(sessionIds)) {
            throw conflict("Коробки сессии не совпадают с одобренной заявкой");
        }
        OffsetDateTime completedAt = OffsetDateTime.now();
        session.setCompletedAt(completedAt);
        session.setUpdatedAt(completedAt);
        session.setStatus(SessionStatus.COMPLETED);
        // Существующий SQL-триггер выдаёт коробки, освобождает места и ставит заявке FULFILLED.
        sessions.flush();
        entityManager.clear();
        return sessionView(findSession(id));
    }

    private void validateForWithdrawal(WithdrawalRequest request) {
        Depositor depositor = request.getDepositor();
        if (depositor.getStatus() != DepositorStatus.ACTIVE) {
            throw conflict("Депозитор больше не активен");
        }
        Contract contract = contracts.findFirstByDepositor_IdOrderByGeneratedAtDesc(depositor.getId())
                .orElseThrow(() -> conflict("У депозитора нет договора"));
        LocalDate today = LocalDate.now();
        if (contract.getStatus() != ContractStatus.VERIFIED
                || (contract.getValidFrom() != null && contract.getValidFrom().isAfter(today))
                || (contract.getValidTo() != null && contract.getValidTo().isBefore(today))) {
            throw conflict("Договор не верифицирован или не действует на текущую дату");
        }
        if (request.getBoxes().isEmpty()) throw conflict("В заявке нет коробок");
        for (Box box : request.getBoxes()) {
            if (!box.getBatch().getId().equals(request.getBatch().getId())
                    || !box.getBatch().getDepositor().getId().equals(depositor.getId())) {
                throw conflict("Коробка не принадлежит партии и владельцу заявки");
            }
            requirePlaced(box);
        }
    }

    private List<WithdrawalRequestView> listRequests(WithdrawalStatus status) {
        List<WithdrawalRequest> selected = status == null ? requests.findAllByOrderBySubmittedAtAsc()
                : requests.findAllByStatusOrderBySubmittedAtAsc(status);
        List<WithdrawalRequestView> result = new ArrayList<>();
        for (WithdrawalRequest request : selected) result.add(requestView(request));
        return result;
    }

    private void checkOwner(AuthPrincipal principal, Long ownerId) {
        if (!principal.id().equals(ownerId)) throw notFound("Заявка или партия");
    }

    private void requirePlaced(Box box) {
        if (box.getStatus() != BoxStatus.PLACED || box.getStoragePlace() == null) {
            throw conflict("В заявку можно включать только размещённые коробки");
        }
    }

    private void requireStatus(WithdrawalRequest request, WithdrawalStatus expected) {
        if (request.getStatus() != expected) {
            throw conflict("Ожидался статус " + expected + ", текущий: " + request.getStatus());
        }
    }

    private void requirePlanned(WithdrawalSession session) {
        if (session.getStatus() != SessionStatus.PLANNED) throw conflict("Сессия уже завершена или отменена");
    }

    private Batch lockBatch(Long id) {
        return batches.findByIdForUpdate(id).orElseThrow(() -> notFound("Партия"));
    }

    private WithdrawalRequest findRequest(Long id) {
        return requests.findById(id).orElseThrow(() -> notFound("Заявка"));
    }

    private WithdrawalRequest lockRequest(Long id) {
        Long batchId = requests.findBatchIdById(id).orElseThrow(() -> notFound("Заявка"));
        lockBatch(batchId);
        return findRequest(id);
    }

    private WithdrawalSession findSession(Long id) {
        return sessions.findById(id).orElseThrow(() -> notFound("Сессия"));
    }

    private WithdrawalSession lockSession(Long id) {
        Long batchId = sessions.findBatchIdById(id).orElseThrow(() -> notFound("Сессия"));
        lockBatch(batchId);
        return findSession(id);
    }

    private WithdrawalRequestView requestView(WithdrawalRequest request) {
        WithdrawalSessionSummary session = null;
        var planned = sessions.findByRequest_Id(request.getId());
        if (planned.isPresent()) {
            WithdrawalSession value = planned.get();
            session = new WithdrawalSessionSummary(value.getId(), value.getPlannedDate(), value.getStatus(), value.getCompletedAt());
        }
        return new WithdrawalRequestView(
                request.getId(), request.getBatch().getId(), request.getBatch().getNumber(),
                request.getDepositor().getId(), request.getDepositor().getLegalName(),
                request.getReason(), request.getDesiredDate(), request.getStatus(), request.getSubmittedAt(),
                request.getCurator() == null ? null : request.getCurator().getId(), request.getCuratorDecisionAt(),
                request.getAdmin() == null ? null : request.getAdmin().getId(), request.getAdminDecisionAt(),
                request.getRejectionReason(), session, boxViews(request.getBoxes()));
    }

    private WithdrawalSessionView sessionView(WithdrawalSession session) {
        return new WithdrawalSessionView(session.getId(), session.getRequest().getId(), session.getCurator().getId(),
                session.getPlannedDate(), session.getStatus(), session.getCompletedAt(),
                session.getRequest().getStatus(), boxViews(session.getBoxes()));
    }

    private List<WithdrawalBoxView> boxViews(List<Box> selected) {
        List<WithdrawalBoxView> result = new ArrayList<>();
        for (Box box : selected) {
            StoragePlaceView location = null;
            if (box.getStatus() == BoxStatus.PLACED && box.getStoragePlace() != null) {
                StoragePlace place = box.getStoragePlace();
                location = new StoragePlaceView(place.getId(), place.getChamber().getId(),
                        place.getChamber().getCode(), place.getRackNo(), place.getShelfNo(), place.getRowNo());
            }
            result.add(new WithdrawalBoxView(box.getId(), box.getSeqNo(), box.getBarcode(), box.getStatus(),
                    location, box.getWithdrawnAt()));
        }
        return result;
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }

    private ResponseStatusException notFound(String object) {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, object + " не найдена");
    }
}
