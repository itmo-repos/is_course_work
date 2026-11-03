package ru.ifmo.is.backend.dto.storage;

import ru.ifmo.is.backend.entitiy.enums.BoxStatus;

import java.time.OffsetDateTime;

public record StoredBoxView(
        Long id,
        short seqNo,
        String barcode,
        BoxStatus status,
        String writeOffReason,
        OffsetDateTime placedAt,
        StoragePlaceView storagePlace
) {}
