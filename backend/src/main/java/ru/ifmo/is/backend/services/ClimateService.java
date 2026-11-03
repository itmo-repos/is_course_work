package ru.ifmo.is.backend.services;

import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.climate.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.ClimateReading;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.mapper.ClimateMapper;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ClimateService {
    private final ChamberRepository chambers;
    private final ClimateReadingRepository readings;
    private final BoxRepository boxes;
    private final AccessService access;
    private final ClimateMapper mapper;
    private final EntityManager entityManager;

    public List<ChamberClimateView> chambers(AuthPrincipal principal) {
        access.requireAnyRole(principal, RoleCode.ENGINEER, RoleCode.ADMIN);
        List<ChamberClimateView> result = new ArrayList<>();
        for (Chamber chamber : chambers.findAllByOrderByCodeAsc()) {
            result.add(view(chamber));
        }
        return result;
    }

    public ChamberClimateView current(AuthPrincipal principal, Long chamberId) {
        access.requireAnyRole(principal, RoleCode.ENGINEER, RoleCode.ADMIN);
        return view(findChamber(chamberId));
    }

    @Transactional
    public ChamberClimateView configure(AuthPrincipal principal, Long chamberId, ClimateSettingsRequest request) {
        access.requireRole(principal, RoleCode.ADMIN);
        validateBounds(request.minTemperature(), request.maxTemperature(), request.climateControlled());
        validateBounds(request.minHumidity(), request.maxHumidity(), request.climateControlled());
        Chamber chamber = lockChamber(chamberId);
        if (request.status() == ChamberStatus.MOTHBALLED && boxes.existsByStoragePlace_Chamber_Id(chamberId)) {
            throw conflict("Нельзя законсервировать камеру с размещёнными или зарезервированными коробками");
        }
        chamber.setStatus(request.status());
        chamber.setClimateControlled(request.climateControlled());
        chamber.setMinTemperature(request.minTemperature());
        chamber.setMaxTemperature(request.maxTemperature());
        chamber.setMinHumidity(request.minHumidity());
        chamber.setMaxHumidity(request.maxHumidity());
        return view(chamber);
    }

    public PageView<ClimateReadingView> history(AuthPrincipal principal, Long chamberId, OffsetDateTime from,
                                               OffsetDateTime to, int page, int size) {
        access.requireAnyRole(principal, RoleCode.ENGINEER, RoleCode.ADMIN);
        validatePeriod(from, to);
        findChamber(chamberId);
        Page<ClimateReading> result = readings.findByChamber_IdAndMeasuredAtBetweenOrderByMeasuredAtAsc(
                chamberId, utc(from), utc(to), PageRequest.of(page, size));
        return new PageView<>(result.map(mapper::reading).getContent(), result.getTotalElements(), page, size);
    }

    public byte[] csv(AuthPrincipal principal, Long chamberId, OffsetDateTime from, OffsetDateTime to) {
        access.requireAnyRole(principal, RoleCode.ENGINEER, RoleCode.ADMIN);
        validatePeriod(from, to);
        findChamber(chamberId);
        StringBuilder csv = new StringBuilder("\uFEFFchamberId,measuredAt,temperature,humidity\r\n");
        // CSV содержит весь период, а не только страницу, видимую на экране.
        for (ClimateReading reading : readings.findByChamber_IdAndMeasuredAtBetweenOrderByMeasuredAtAsc(chamberId, utc(from), utc(to))) {
            csv.append(chamberId).append(',').append(reading.getMeasuredAt().atOffset(ZoneOffset.UTC)).append(',')
                    .append(reading.getTemperature().toPlainString()).append(',')
                    .append(reading.getHumidity().toPlainString()).append("\r\n");
        }
        return csv.toString().getBytes(StandardCharsets.UTF_8);
    }

    private void validateBounds(BigDecimal min, BigDecimal max, boolean required) {
        if (required && (min == null || max == null)) {
            throw badRequest("При включённом климат-контроле нужны все четыре границы");
        }
        if (min != null && max != null && min.compareTo(max) >= 0) {
            throw badRequest("Нижняя граница должна быть меньше верхней");
        }
    }

    private void validatePeriod(OffsetDateTime from, OffsetDateTime to) {
        if (from.isAfter(to)) throw badRequest("Начало периода должно быть не позже конца");
    }

    private LocalDateTime utc(OffsetDateTime time) {
        return time.withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime();
    }

    private Chamber findChamber(Long id) {
        return chambers.findById(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
    }

    private Chamber lockChamber(Long id) {
        Chamber chamber = chambers.findByIdForUpdate(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
        entityManager.refresh(chamber, LockModeType.PESSIMISTIC_WRITE);
        return chamber;
    }

    private ChamberClimateView view(Chamber chamber) {
        return mapper.chamber(chamber, readings.findFirstByChamber_IdOrderByMeasuredAtDesc(chamber.getId()).orElse(null));
    }

    private ResponseStatusException conflict(String message) {
        return new ResponseStatusException(HttpStatus.CONFLICT, message);
    }

    private ResponseStatusException badRequest(String message) {
        return new ResponseStatusException(HttpStatus.BAD_REQUEST, message);
    }
}
