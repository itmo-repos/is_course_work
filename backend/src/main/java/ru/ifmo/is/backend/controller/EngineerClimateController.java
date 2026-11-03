package ru.ifmo.is.backend.controller;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.climate.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.ClimateService;

import java.time.OffsetDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/engineer/chambers")
@RequiredArgsConstructor
public class EngineerClimateController {
    private final ClimateService service;

    @GetMapping
    public List<ChamberClimateView> chambers(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.chambers(principal);
    }

    @GetMapping("/{id}")
    public ChamberClimateView current(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.current(principal, id);
    }

    @GetMapping("/{id}/readings")
    public PageView<ClimateReadingView> history(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "100") @Min(1) @Max(200) int size) {
        return service.history(principal, id, from, to, page, size);
    }

    @GetMapping(value = "/{id}/readings.csv", produces = "text/csv;charset=UTF-8")
    public ResponseEntity<byte[]> csv(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to) {
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=chamber-" + id + "-climate.csv").body(service.csv(principal, id, from, to));
    }
}
