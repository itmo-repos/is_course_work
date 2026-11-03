package ru.ifmo.is.backend.dto.common;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ReasonRequest(
        @NotBlank @Size(max = 2000) String reason
) {}
