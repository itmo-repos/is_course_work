package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.pass.*;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AccessJournalService {
    private final AccessEventRepository events;
    private final VaultPassService passes;
    private final ChamberRepository chambers;
    private final AccessService access;
    private final EntityManager entityManager;

    @Transactional
    public AccessEventView record(AuthPrincipal principal, AccessEventRequest request) {
        access.requireAnyRole(principal, RoleCode.SECURITY, RoleCode.ADMIN);
        Employee registrar = access.requireStaff(principal);
        VaultPass pass = passes.lockByCode(request.passCode());
        if (pass.getEmployee() != null && !pass.getEmployee().isActive()) {
            throw conflict("Владелец пропуска неактивен");
        }
        if (pass.getIntakeSession() != null && pass.getIntakeSession().getStatus() != SessionStatus.PLANNED) {
            throw conflict("Сессия приёма закрыта");
        }
        if (pass.getChambers().stream().noneMatch(c -> c.getId().equals(request.chamberId()))) {
            throw conflict("Пропуск не разрешает доступ в эту камеру");
        }
        Chamber chamber = chambers.findByIdForUpdate(request.chamberId()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        entityManager.refresh(chamber, LockModeType.PESSIMISTIC_WRITE);
        if (chamber.getStatus() != ChamberStatus.ACTIVE) throw conflict("Камера неактивна");
        LocalDateTime now = LocalDateTime.now(ZoneOffset.UTC);
        if (passes.effectiveStatus(pass) != PassStatus.ACTIVE || now.isBefore(pass.getValidFrom())) {
            throw conflict("Пропуск отозван, истёк или ещё не начал действовать");
        }
        AccessEvent event = new AccessEvent();
        event.setPass(pass);
        event.setEmployee(pass.getEmployee());
        event.setChamber(chamber);
        event.setDirection(request.direction());
        event.setOccurredAt(now);
        event.setComment(request.comment());
        event.setRegisteredBy(registrar);
        return view(events.save(event));
    }

    public PageView<AccessEventView> history(AuthPrincipal principal, Long passId, Long employeeId, Long chamberId,
                                            OffsetDateTime from, OffsetDateTime to, int page, int size) {
        access.requireAnyRole(principal, RoleCode.SECURITY, RoleCode.ADMIN);
        if (from.isAfter(to)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Начало периода позже конца");
        var result = events.history(passId, employeeId, chamberId, utc(from), utc(to), PageRequest.of(page, size));
        return new PageView<>(result.map(this::view).getContent(), result.getTotalElements(), page, size);
    }

    private AccessEventView view(AccessEvent event) {
        return new AccessEventView(event.getId(), event.getPass().getId(),
                event.getEmployee() == null ? null : event.getEmployee().getId(), event.getChamber().getId(),
                event.getDirection(), event.getOccurredAt().atOffset(ZoneOffset.UTC), event.getComment(),
                event.getRegisteredBy() == null ? null : event.getRegisteredBy().getId());
    }

    private LocalDateTime utc(OffsetDateTime value) {
        return value.withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime();
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
