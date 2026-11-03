package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.common.ReasonRequest;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalRequestView;
import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.WithdrawalService;

import java.util.List;

@RestController
@RequestMapping("/api/admin/withdrawal-requests")
@RequiredArgsConstructor
public class AdminWithdrawalController {
    private final WithdrawalService service;

    @GetMapping
    public List<WithdrawalRequestView> list(@AuthenticationPrincipal AuthPrincipal principal,
                                  @RequestParam(required = false) WithdrawalStatus status) {
        return service.adminRequests(principal, status);
    }

    @GetMapping("/{id}")
    public WithdrawalRequestView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.adminRequest(principal, id);
    }

    @PostMapping("/{id}/approve")
    public WithdrawalRequestView approve(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.adminApprove(principal, id);
    }

    @PostMapping("/{id}/reject")
    public WithdrawalRequestView reject(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody ReasonRequest request) {
        return service.adminReject(principal, id, request.reason());
    }
}
