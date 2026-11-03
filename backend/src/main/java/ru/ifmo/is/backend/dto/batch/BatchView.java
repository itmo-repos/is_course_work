package ru.ifmo.is.backend.dto.batch;

import ru.ifmo.is.backend.entitiy.enums.BatchStatus;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public record BatchView(
        Long id,
        String number,
        Long depositorId,
        BatchStatus status,
        LocalDate desiredShipmentDate,
        OffsetDateTime formedAt,
        OffsetDateTime confirmedAt,
        OffsetDateTime arrivedAt,
        String trackingNumber,
        String rejectionReason,
        int boxCount,
        List<BoxView> boxes
) {}
