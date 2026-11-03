package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.climate.ClimateReadingView;
import ru.ifmo.is.backend.dto.gateway.GatewayReadingRequest;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.ClimateReading;
import ru.ifmo.is.backend.entitiy.GatewayKey;
import ru.ifmo.is.backend.entitiy.enums.ChamberStatus;
import ru.ifmo.is.backend.entitiy.enums.ClimateParameter;
import ru.ifmo.is.backend.mapper.ClimateMapper;
import ru.ifmo.is.backend.repository.ChamberRepository;
import ru.ifmo.is.backend.repository.ClimateReadingRepository;
import ru.ifmo.is.backend.repository.GatewayKeyRepository;
import ru.ifmo.is.backend.security.GatewayKeyHasher;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

@Service
@RequiredArgsConstructor
public class GatewayReadingService {
    private final GatewayKeyRepository keys;
    private final GatewayKeyHasher hasher;
    private final ChamberRepository chambers;
    private final ClimateReadingRepository readings;
    private final NotificationService notifications;
    private final ClimateMapper mapper;
    private final EntityManager entityManager;

    @Transactional
    public ClimateReadingView record(String authorization, GatewayReadingRequest request) {
        String hash = hasher.hashAuthorization(authorization);
        // Общая блокировка с удалением: после завершённого удаления ключ уже не запишет показания.
        GatewayKey key = keys.findByHashForUpdate(hash).orElseThrow(hasher::unauthorized);
        // Камера берётся только из ключа. Ни тело, ни URL запроса её не выбирают.
        Chamber chamber = chambers.findByIdForUpdate(key.getChamber().getId()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        entityManager.refresh(chamber, LockModeType.PESSIMISTIC_WRITE);
        if (chamber.getStatus() != ChamberStatus.ACTIVE || !chamber.isClimateControlled()) {
            throw conflict("Климат-контроль камеры выключен или камера неактивна");
        }
        if (chamber.getMinTemperature() == null || chamber.getMaxTemperature() == null
                || chamber.getMinHumidity() == null || chamber.getMaxHumidity() == null) {
            throw conflict("Сначала настройте границы климата камеры");
        }
        LocalDateTime time = request.measuredAt().withOffsetSameInstant(ZoneOffset.UTC)
                .toLocalDateTime().truncatedTo(ChronoUnit.MICROS);
        var existing = readings.findByChamber_IdAndMeasuredAt(chamber.getId(), time);
        if (existing.isPresent()) {
            ClimateReading reading = existing.get();
            if (reading.getTemperature().compareTo(request.temperature()) != 0
                    || reading.getHumidity().compareTo(request.humidity()) != 0) {
                throw conflict("На это время уже сохранено измерение с другими значениями");
            }
            return mapper.reading(reading);
        }
        ClimateReading reading = new ClimateReading();
        reading.setChamber(chamber);
        reading.setMeasuredAt(time);
        reading.setTemperature(request.temperature());
        reading.setHumidity(request.humidity());
        readings.save(reading);
        notifyIfOutsideBounds(reading);
        return mapper.reading(reading);
    }

    private void notifyIfOutsideBounds(ClimateReading reading) {
        Chamber chamber = reading.getChamber();
        boolean temperature = outside(reading.getTemperature(), chamber.getMinTemperature(), chamber.getMaxTemperature());
        boolean humidity = outside(reading.getHumidity(), chamber.getMinHumidity(), chamber.getMaxHumidity());
        if (!temperature && !humidity) return;
        ClimateParameter parameter = temperature && humidity ? ClimateParameter.BOTH
                : temperature ? ClimateParameter.TEMPERATURE : ClimateParameter.HUMIDITY;
        String message = "Камера " + chamber.getCode() + ": отклонение " + parameter
                + "; температура " + reading.getTemperature() + " °C (норма " + chamber.getMinTemperature()
                + "…" + chamber.getMaxTemperature() + "), влажность " + reading.getHumidity() + " % (норма "
                + chamber.getMinHumidity() + "…" + chamber.getMaxHumidity() + "); время "
                + reading.getMeasuredAt().atOffset(ZoneOffset.UTC);
        notifications.climateAlert(reading, parameter, message);
    }

    private boolean outside(BigDecimal value, BigDecimal min, BigDecimal max) {
        return value.compareTo(min) < 0 || value.compareTo(max) > 0;
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }
}
