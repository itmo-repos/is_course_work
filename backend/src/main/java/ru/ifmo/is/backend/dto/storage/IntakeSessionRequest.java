package ru.ifmo.is.backend.dto.storage;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.time.LocalDate;

public record IntakeSessionRequest(
        @NotNull @Positive Long chamberId,
        @NotNull @FutureOrPresent LocalDate plannedDate
) {}
