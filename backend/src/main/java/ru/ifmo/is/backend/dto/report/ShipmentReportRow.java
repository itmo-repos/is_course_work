package ru.ifmo.is.backend.dto.report;

import java.time.OffsetDateTime;

public record ShipmentReportRow(Long eventId, Long batchId, String batchNumber,
        Long depositorId, String depositorName, String event, OffsetDateTime occurredAt,
        long boxCount, String source) {}
