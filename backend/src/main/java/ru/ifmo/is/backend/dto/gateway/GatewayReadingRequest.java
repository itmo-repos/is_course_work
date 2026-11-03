package ru.ifmo.is.backend.dto.gateway;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record GatewayReadingRequest(
        @NotNull @PastOrPresent OffsetDateTime measuredAt,
        @NotNull @DecimalMin("-80") @DecimalMax("60") @Digits(integer = 2, fraction = 2) BigDecimal temperature,
        @NotNull @DecimalMin("0") @DecimalMax("100") @Digits(integer = 3, fraction = 2) BigDecimal humidity
) {
    // Камеру и другие поля клиенту выбирать нельзя. Не игнорируем попытки их передать.
    @JsonAnySetter
    public void rejectUnknown(String name, Object value) {
        throw new IllegalArgumentException("Неизвестное поле измерения");
    }
}
