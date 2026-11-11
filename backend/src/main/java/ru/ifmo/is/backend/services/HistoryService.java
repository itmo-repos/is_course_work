package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.audit.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.AuditEventRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class HistoryService {
    private final AuditEventRepository events;
    private final BatchAccessService batches;
    private final AccessService access;

    public PageView<AuditView> audit(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to,
            String actorType, Long actorId, String action, String entityType, Long entityId, Long batchId, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        if (from.isAfter(to)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Начало периода позже конца");
        var result = events.search(from.withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime(),
                to.withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime(), actorType, actorId, action,
                entityType, entityId, batchId, PageRequest.of(page, size));
        return new PageView<>(result.map(e -> new AuditView(e.getId(), e.getActorType(), e.getActorId(), e.getAction(),
                e.getEntityType(), e.getEntityId(), e.getBatchId(), e.getMessage(), e.getDetails(),
                e.getOccurredAt().atOffset(ZoneOffset.UTC))).getContent(), result.getTotalElements(), page, size);
    }

    public PageView<BatchHistoryView> batch(AuthPrincipal principal, Long id, int page, int size) {
        access.requireAnyRole(principal, RoleCode.CURATOR, RoleCode.ADMIN);
        batches.find(id);
        return history(id, page, size);
    }

    public PageView<BatchHistoryView> ownBatch(AuthPrincipal principal, Long id, int page, int size) {
        batches.owned(principal, id);
        return history(id, page, size);
    }

    private PageView<BatchHistoryView> history(Long id, int page, int size) {
        var result = events.findByBatchIdOrderByOccurredAtAscIdAsc(id, PageRequest.of(page, size));
        // Технические детали, включая координаты резервов, доступны только в административном аудите.
        return new PageView<>(result.map(e -> new BatchHistoryView(e.getId(), e.getAction(), e.getEntityType(),
                e.getEntityId(), e.getMessage(), e.getOccurredAt().atOffset(ZoneOffset.UTC))).getContent(),
                result.getTotalElements(), page, size);
    }
}
