package ru.ifmo.is.backend.dto.storage;

public record StoragePlaceView(
        Long id,
        Long chamberId,
        String chamberCode,
        short rackNo,
        short shelfNo,
        short rowNo
) {}
