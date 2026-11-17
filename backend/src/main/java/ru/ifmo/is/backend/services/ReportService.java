package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.report.*;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.ReportRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Locale;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
public class ReportService {
    private final ReportRepository reports;
    private final AccessService access;

    public ReportView<OccupancyReportRow> occupancy(AuthPrincipal principal, Long chamberId, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        return view(reports.occupancy(chamberId,page,size));
    }

    public byte[] occupancyCsv(AuthPrincipal principal, Long chamberId) {
        access.requireRole(principal, RoleCode.ADMIN);
        ReportCsv csv = new ReportCsv("chamberId","code","name","status","total","free","reserved","occupied",
                "unserviceable","available","occupiedPercent","assignedPercent");
        reports.occupancy(chamberId,r -> csv.row(r.chamberId(),r.code(),r.name(),r.status(),r.total(),r.free(),
                r.reserved(),r.occupied(),r.unserviceable(),r.available(),r.occupiedPercent(),r.assignedPercent()));
        return csv.bytes();
    }

    public ReportView<DepositorReportRow> depositors(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to,
            Long depositorId, String countryCode, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        optionalPeriod(from,to);
        return view(reports.depositors(utc(from),utc(to),depositorId,country(countryCode),page,size));
    }

    public byte[] depositorsCsv(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to,
                                Long depositorId, String countryCode) {
        access.requireRole(principal, RoleCode.ADMIN);
        optionalPeriod(from,to);
        ReportCsv csv = new ReportCsv("depositorId","legalName","countryCode","activatedAt","contractNumber",
                "validFrom","validTo","batchCount","reservedBoxes","placedBoxes","storedSamples");
        reports.depositors(utc(from),utc(to),depositorId,country(countryCode),r -> csv.row(r.depositorId(),r.legalName(),
                r.countryCode(),r.activatedAt(),r.contractNumber(),r.validFrom(),r.validTo(),r.batchCount(),
                r.reservedBoxes(),r.placedBoxes(),r.storedSamples()));
        return csv.bytes();
    }

    public ReportView<ShipmentReportRow> shipments(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to,
                                                   Long depositorId, Long batchId, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        period(from,to);
        return view(reports.shipments(utc(from),utc(to),depositorId,batchId,page,size));
    }

    public byte[] shipmentsCsv(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to, Long depositorId, Long batchId) {
        access.requireRole(principal, RoleCode.ADMIN);
        period(from,to);
        ReportCsv csv = new ReportCsv("eventId","batchId","batchNumber","depositorId","depositorName","event",
                "occurredAt","boxCount","source");
        reports.shipments(utc(from),utc(to),depositorId,batchId,r -> csv.row(r.eventId(),r.batchId(),r.batchNumber(),
                r.depositorId(),r.depositorName(),r.event(),r.occurredAt(),r.boxCount(),r.source()));
        return csv.bytes();
    }

    public ReportView<WithdrawalReportRow> withdrawals(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to,
                                                       Long depositorId, Long batchId, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        period(from,to);
        return view(reports.withdrawals(utc(from),utc(to),depositorId,batchId,page,size));
    }

    public byte[] withdrawalsCsv(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to, Long depositorId, Long batchId) {
        access.requireRole(principal, RoleCode.ADMIN);
        period(from,to);
        ReportCsv csv = new ReportCsv("sessionId","requestId","batchId","batchNumber","depositorId","depositorName",
                "curatorId","plannedDate","completedAt","boxCount","sampleCount","seedQuantity");
        reports.withdrawals(utc(from),utc(to),depositorId,batchId,r -> csv.row(r.sessionId(),r.requestId(),r.batchId(),
                r.batchNumber(),r.depositorId(),r.depositorName(),r.curatorId(),r.plannedDate(),r.completedAt(),
                r.boxCount(),r.sampleCount(),r.seedQuantity()));
        return csv.bytes();
    }

    public ReportView<ClimateIncidentReportRow> incidents(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to,
                                                         Long chamberId, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        period(from,to);
        return view(reports.incidents(utc(from),utc(to),chamberId,page,size));
    }

    public byte[] incidentsCsv(AuthPrincipal principal, OffsetDateTime from, OffsetDateTime to, Long chamberId) {
        access.requireRole(principal, RoleCode.ADMIN);
        period(from,to);
        ReportCsv csv = new ReportCsv("readingId","chamberId","chamberCode","measuredAt","temperature","humidity",
                "minTemperature","maxTemperature","minHumidity","maxHumidity","parameter");
        reports.incidents(utc(from),utc(to),chamberId,r -> csv.row(r.readingId(),r.chamberId(),r.chamberCode(),r.measuredAt(),
                r.temperature(),r.humidity(),r.minTemperature(),r.maxTemperature(),r.minHumidity(),r.maxHumidity(),r.parameter()));
        return csv.bytes();
    }

    private void period(OffsetDateTime from, OffsetDateTime to) {
        if (from == null || to == null || from.isAfter(to)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Нужны from и to; начало периода не позже конца");
        }
    }

    private void optionalPeriod(OffsetDateTime from, OffsetDateTime to) {
        if (from != null || to != null) period(from,to);
    }

    private LocalDateTime utc(OffsetDateTime value) {
        return value == null ? null : value.withOffsetSameInstant(ZoneOffset.UTC).toLocalDateTime();
    }

    private String country(String value) {
        return value == null ? null : value.toUpperCase(Locale.ROOT);
    }

    private <T> ReportView<T> view(PageView<T> page) {
        return new ReportView<>(OffsetDateTime.now(ZoneOffset.UTC),page.items(),page.total(),page.page(),page.size());
    }
}
