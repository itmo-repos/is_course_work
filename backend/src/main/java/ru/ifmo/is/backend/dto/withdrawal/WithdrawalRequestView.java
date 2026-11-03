package ru.ifmo.is.backend.dto.withdrawal;

import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public record WithdrawalRequestView(
        Long id,
        Long batchId,
        String batchNumber,
        Long depositorId,
        String depositorName,
        String reason,
        LocalDate desiredDate,
        WithdrawalStatus status,
        OffsetDateTime submittedAt,
        Long curatorId,
        OffsetDateTime curatorDecisionAt,
        Long adminId,
        OffsetDateTime adminDecisionAt,
        String rejectionReason,
        WithdrawalSessionSummary session,
        List<WithdrawalBoxView> boxes
) {}
