package ru.ifmo.is.backend.dto.report;

import ru.ifmo.is.backend.entitiy.enums.ClimateParameter;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ClimateIncidentReportRow(Long readingId, Long chamberId, String chamberCode,
        OffsetDateTime measuredAt, BigDecimal temperature, BigDecimal humidity,
        BigDecimal minTemperature, BigDecimal maxTemperature, BigDecimal minHumidity,
        BigDecimal maxHumidity, ClimateParameter parameter) {}
