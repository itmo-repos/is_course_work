package ru.ifmo.is.backend.dto.climate;

import jakarta.validation.constraints.*;
import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import java.math.BigDecimal;

public record ClimateSettingsRequest(
        @NotNull ChamberStatus status,
        @NotNull Boolean climateControlled,
        @DecimalMin("-80") @DecimalMax("60") @Digits(integer = 2, fraction = 2) BigDecimal minTemperature,
        @DecimalMin("-80") @DecimalMax("60") @Digits(integer = 2, fraction = 2) BigDecimal maxTemperature,
        @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2) BigDecimal minHumidity,
        @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2) BigDecimal maxHumidity
) {}
