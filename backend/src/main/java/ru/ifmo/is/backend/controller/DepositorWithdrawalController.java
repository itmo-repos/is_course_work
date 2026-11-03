package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalRequestData;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalRequestView;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.WithdrawalService;

import java.util.List;

@RestController
@RequestMapping("/api/depositors/me/withdrawal-requests")
@RequiredArgsConstructor
public class DepositorWithdrawalController {
    private final WithdrawalService service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WithdrawalRequestView submit(@AuthenticationPrincipal AuthPrincipal principal, @Valid @RequestBody WithdrawalRequestData request) {
        return service.submit(principal, request.batchId(), request.boxIds(), request.reason(), request.desiredDate());
    }

    @GetMapping
    public List<WithdrawalRequestView> list(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.ownRequests(principal);
    }

    @GetMapping("/{id}")
    public WithdrawalRequestView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.ownRequest(principal, id);
    }
}
