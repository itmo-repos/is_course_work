package ru.ifmo.is.backend.dto.withdrawal;

import ru.ifmo.is.backend.entitiy.enums.SessionStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record WithdrawalSessionSummary(
        Long id,
        LocalDate plannedDate,
        SessionStatus status,
        OffsetDateTime completedAt
) {}
