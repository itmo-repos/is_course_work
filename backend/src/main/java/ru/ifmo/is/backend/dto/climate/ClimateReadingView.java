package ru.ifmo.is.backend.dto.climate;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record ClimateReadingView(Long id, Long chamberId, OffsetDateTime measuredAt,
                                 BigDecimal temperature, BigDecimal humidity) {}
