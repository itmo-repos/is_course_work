package ru.ifmo.is.backend.dto.batch;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record BoxData(
        @NotEmpty @Size(max = 100) List<@NotNull @Valid SampleData> samples
) {}
