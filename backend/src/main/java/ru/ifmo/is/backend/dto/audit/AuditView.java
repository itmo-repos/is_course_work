package ru.ifmo.is.backend.dto.audit;

import java.time.OffsetDateTime;

public record AuditView(Long id, String actorType, Long actorId, String action, String entityType,
                        Long entityId, Long batchId, String message, String details, OffsetDateTime occurredAt) {}
