package ru.ifmo.is.backend.dto.audit;

import java.time.OffsetDateTime;

public record BatchHistoryView(Long id, String action, String entityType, Long entityId,
                               String message, OffsetDateTime occurredAt) {}
