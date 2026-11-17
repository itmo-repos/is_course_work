package ru.ifmo.is.backend.controller;

import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.report.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.ReportService;
import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/admin/reports")
@RequiredArgsConstructor
public class ReportController {
    private final ReportService service;

    @GetMapping("/occupancy")
    public ReportView<OccupancyReportRow> occupancy(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(required=false) @Positive Long chamberId,
            @RequestParam(defaultValue="0") @Min(0) int page,
            @RequestParam(defaultValue="50") @Min(1) @Max(200) int size) {
        return service.occupancy(principal,chamberId,page,size);
    }

    @GetMapping(value="/occupancy.csv", produces="text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> occupancyCsv(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(required=false) @Positive Long chamberId) {
        return csv(service.occupancyCsv(principal,chamberId),"occupancy");
    }

    @GetMapping("/depositors")
    public ReportView<DepositorReportRow> depositors(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(required=false) OffsetDateTime from, @RequestParam(required=false) OffsetDateTime to,
            @RequestParam(required=false) @Positive Long depositorId,
            @RequestParam(required=false) @Pattern(regexp="[A-Za-z]{2}") String countryCode,
            @RequestParam(defaultValue="0") @Min(0) int page,
            @RequestParam(defaultValue="50") @Min(1) @Max(200) int size) {
        return service.depositors(principal,from,to,depositorId,countryCode,page,size);
    }

    @GetMapping(value="/depositors.csv", produces="text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> depositorsCsv(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(required=false) OffsetDateTime from, @RequestParam(required=false) OffsetDateTime to,
            @RequestParam(required=false) @Positive Long depositorId,
            @RequestParam(required=false) @Pattern(regexp="[A-Za-z]{2}") String countryCode) {
        return csv(service.depositorsCsv(principal,from,to,depositorId,countryCode),"depositors");
    }

    @GetMapping("/shipments")
    public ReportView<ShipmentReportRow> shipments(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required=false) @Positive Long depositorId,
            @RequestParam(required=false) @Positive Long batchId,
            @RequestParam(defaultValue="0") @Min(0) int page,
            @RequestParam(defaultValue="50") @Min(1) @Max(200) int size) {
        return service.shipments(principal,from,to,depositorId,batchId,page,size);
    }

    @GetMapping(value="/shipments.csv", produces="text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> shipmentsCsv(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required=false) @Positive Long depositorId,
            @RequestParam(required=false) @Positive Long batchId) {
        return csv(service.shipmentsCsv(principal,from,to,depositorId,batchId),"shipments");
    }

    @GetMapping("/withdrawals")
    public ReportView<WithdrawalReportRow> withdrawals(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required=false) @Positive Long depositorId,
            @RequestParam(required=false) @Positive Long batchId,
            @RequestParam(defaultValue="0") @Min(0) int page,
            @RequestParam(defaultValue="50") @Min(1) @Max(200) int size) {
        return service.withdrawals(principal,from,to,depositorId,batchId,page,size);
    }

    @GetMapping(value="/withdrawals.csv", produces="text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> withdrawalsCsv(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required=false) @Positive Long depositorId,
            @RequestParam(required=false) @Positive Long batchId) {
        return csv(service.withdrawalsCsv(principal,from,to,depositorId,batchId),"withdrawals");
    }

    @GetMapping("/climate-incidents")
    public ReportView<ClimateIncidentReportRow> incidents(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required=false) @Positive Long chamberId,
            @RequestParam(defaultValue="0") @Min(0) int page,
            @RequestParam(defaultValue="50") @Min(1) @Max(200) int size) {
        return service.incidents(principal,from,to,chamberId,page,size);
    }

    @GetMapping(value="/climate-incidents.csv", produces="text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> incidentsCsv(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required=false) @Positive Long chamberId) {
        return csv(service.incidentsCsv(principal,from,to,chamberId),"climate-incidents");
    }

    private ResponseEntity<byte[]> csv(byte[] contents, String filename) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .header(HttpHeaders.CONTENT_DISPOSITION,"attachment; filename=" + filename + ".csv").body(contents);
    }
}
