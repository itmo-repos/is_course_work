package ru.ifmo.is.backend.dto.withdrawal;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record WithdrawalSessionRequest(
        @NotNull @FutureOrPresent LocalDate plannedDate
) {}
