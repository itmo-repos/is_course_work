package ru.ifmo.is.backend.dto.batch;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record SampleData(
        @NotNull @Positive Long speciesId,
        @NotBlank @Pattern(regexp = "[A-Za-z]{2}") String originCountryCode,
        @NotNull @Min(1850) @Max(2900) Integer collectionYear,
        @NotNull @Positive Integer seedQuantity,
        @Size(max = 5000) String note
) {}
