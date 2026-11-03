package ru.ifmo.is.backend.dto.storage;

import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;

import java.util.List;

public record ChamberMapView(
        Long chamberId,
        String code,
        String name,
        ChamberStatus status,
        ChamberMapSummary summary,
        List<StoragePlaceMapView> places
) {}
