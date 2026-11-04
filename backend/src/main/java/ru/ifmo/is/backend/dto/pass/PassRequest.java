package ru.ifmo.is.backend.dto.pass;

import jakarta.validation.constraints.*;
import java.time.OffsetDateTime;
import java.util.Set;

public record PassRequest(@Positive Long employeeId,
                          @NotNull OffsetDateTime validFrom, @NotNull OffsetDateTime validTo,
                          @Size(max = 5000) String comment,
                          @NotEmpty @Size(max = 100) Set<@NotNull @Positive Long> chamberIds) {}
