package ru.ifmo.is.backend.dto.withdrawal;

import ru.ifmo.is.backend.dto.storage.StoragePlaceView;
import ru.ifmo.is.backend.entitiy.enums.BoxStatus;

import java.time.OffsetDateTime;

public record WithdrawalBoxView(
        Long id,
        short seqNo,
        String barcode,
        BoxStatus status,
        StoragePlaceView storagePlace,
        OffsetDateTime withdrawnAt
) {}
