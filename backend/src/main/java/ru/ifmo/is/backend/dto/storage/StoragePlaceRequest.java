package ru.ifmo.is.backend.dto.storage;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record StoragePlaceRequest(
        @NotNull @Positive Long storagePlaceId
) {}
