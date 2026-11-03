package ru.ifmo.is.backend.dto.storage;

public record StoragePlaceMapView(
        Long id,
        short rackNo,
        short shelfNo,
        short rowNo,
        boolean serviceable,
        Occupancy occupancy,
        boolean available,
        AssignedBoxView box
) {}
