package ru.ifmo.is.backend.dto.withdrawal;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;

public record WithdrawalRequestData(
        @NotNull @Positive Long batchId,
        @NotEmpty @Size(max = 100) List<@NotNull @Positive Long> boxIds,
        @NotBlank @Size(max = 2000) String reason,
        @NotNull @FutureOrPresent LocalDate desiredDate
) {}
