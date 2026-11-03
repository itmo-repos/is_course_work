package ru.ifmo.is.backend.dto.climate;

import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import java.math.BigDecimal;

public record ChamberClimateView(Long id, String code, String name, ChamberStatus status,
                                 boolean climateControlled, BigDecimal minTemperature, BigDecimal maxTemperature,
                                 BigDecimal minHumidity, BigDecimal maxHumidity, ClimateReadingView latestReading) {}
