package ru.ifmo.is.backend.dto.batch;

import jakarta.validation.Valid;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;

public record BatchData(
        @NotNull @FutureOrPresent LocalDate desiredShipmentDate,
        @NotEmpty @Size(max = 100) List<@NotNull @Valid BoxData> boxes
) {}
