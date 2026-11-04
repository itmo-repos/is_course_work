package ru.ifmo.is.backend.dto.pass;

import jakarta.validation.constraints.*;
import ru.ifmo.is.backend.entitiy.enums.AccessDirection;

public record AccessEventRequest(@NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{43}") String passCode,
                                 @NotNull @Positive Long chamberId, @NotNull AccessDirection direction,
                                 @Size(max = 5000) String comment) {}
