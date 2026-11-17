package ru.ifmo.is.backend.dto.report;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record WithdrawalReportRow(Long sessionId, Long requestId, Long batchId, String batchNumber,
        Long depositorId, String depositorName, Long curatorId, LocalDate plannedDate,
        OffsetDateTime completedAt, long boxCount, long sampleCount, long seedQuantity) {}
