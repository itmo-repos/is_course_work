package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.climate.ChamberClimateView;
import ru.ifmo.is.backend.dto.climate.ClimateSettingsRequest;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.ClimateService;

@RestController
@RequestMapping("/api/admin/chambers")
@RequiredArgsConstructor
public class AdminClimateController {
    private final ClimateService service;

    @PutMapping("/{id}/settings")
    public ChamberClimateView configure(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                        @Valid @RequestBody ClimateSettingsRequest request) {
        return service.configure(principal, id, request);
    }
}
