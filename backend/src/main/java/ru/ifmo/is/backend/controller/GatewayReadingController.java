package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.climate.ClimateReadingView;
import ru.ifmo.is.backend.dto.gateway.GatewayReadingRequest;
import ru.ifmo.is.backend.services.GatewayReadingService;

@RestController
@RequestMapping("/api/gateway")
@RequiredArgsConstructor
public class GatewayReadingController {
    private final GatewayReadingService service;

    @PostMapping("/readings")
    public ClimateReadingView record(@RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authorization,
                                     @Valid @RequestBody GatewayReadingRequest request) {
        return service.record(authorization, request);
    }
}
