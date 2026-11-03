package ru.ifmo.is.backend.dto.withdrawal;

import ru.ifmo.is.backend.entitiy.enums.SessionStatus;
import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public record WithdrawalSessionView(
        Long id,
        Long requestId,
        Long curatorId,
        LocalDate plannedDate,
        SessionStatus status,
        OffsetDateTime completedAt,
        WithdrawalStatus requestStatus,
        List<WithdrawalBoxView> boxes
) {}
