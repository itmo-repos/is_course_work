package ru.ifmo.is.backend.dto.report;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record DepositorReportRow(Long depositorId, String legalName, String countryCode,
        OffsetDateTime activatedAt, String contractNumber, LocalDate validFrom, LocalDate validTo,
        long batchCount, long reservedBoxes, long placedBoxes, long storedSamples) {}
