package ru.ifmo.is.backend.dto.storage;

import ru.ifmo.is.backend.entitiy.enums.BatchStatus;
import ru.ifmo.is.backend.entitiy.enums.SessionStatus;
import ru.ifmo.is.backend.dto.pass.IssuedPass;
import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public record IntakeSessionView(
        Long id,
        Long batchId,
        BatchStatus batchStatus,
        Long curatorId,
        Long chamberId,
        LocalDate plannedDate,
        SessionStatus status,
        OffsetDateTime completedAt,
        List<StoredBoxView> boxes,
        @JsonInclude(JsonInclude.Include.NON_NULL) IssuedPass issuedPass
) {}
