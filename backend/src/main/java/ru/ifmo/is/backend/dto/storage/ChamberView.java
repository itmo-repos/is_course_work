package ru.ifmo.is.backend.dto.storage;

import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;

public record ChamberView(
        Long id,
        String code,
        String name,
        ChamberStatus status,
        int freePlaceCount
) {}
