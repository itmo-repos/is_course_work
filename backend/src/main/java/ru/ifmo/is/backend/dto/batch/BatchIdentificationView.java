package ru.ifmo.is.backend.dto.batch;

public record BatchIdentificationView(
        Long batchId,
        String batchNumber,
        String depositorName,
        String currentStatus,
        Long boxCount
) {}
