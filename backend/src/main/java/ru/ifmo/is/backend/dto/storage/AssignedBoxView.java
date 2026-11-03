package ru.ifmo.is.backend.dto.storage;

import ru.ifmo.is.backend.entitiy.enums.BatchStatus;
import ru.ifmo.is.backend.entitiy.enums.BoxStatus;

public record AssignedBoxView(
        Long id,
        short seqNo,
        String barcode,
        BoxStatus status,
        Long batchId,
        String batchNumber,
        BatchStatus batchStatus,
        Long depositorId,
        String depositorName
) {}
