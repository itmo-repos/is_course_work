package ru.ifmo.is.backend.dto.batch;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import ru.ifmo.is.backend.entitiy.enums.BatchStatus;

public record BatchTrackingRequest(
        @NotNull BatchStatus status,
        @Size(max = 64) String trackingNumber
) {}
