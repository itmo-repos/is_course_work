package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.common.ReasonRequest;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalRequestView;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalSessionRequest;
import ru.ifmo.is.backend.dto.withdrawal.WithdrawalSessionView;
import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.WithdrawalService;

import java.util.List;

@RestController
@RequestMapping("/api/curator")
@RequiredArgsConstructor
public class CuratorWithdrawalController {
    private final WithdrawalService service;

    @GetMapping("/withdrawal-requests")
    public List<WithdrawalRequestView> list(@AuthenticationPrincipal AuthPrincipal principal,
                                  @RequestParam(required = false) WithdrawalStatus status) {
        return service.curatorRequests(principal, status);
    }

    @GetMapping("/withdrawal-requests/{id}")
    public WithdrawalRequestView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.curatorRequest(principal, id);
    }

    @PostMapping("/withdrawal-requests/{id}/review")
    public WithdrawalRequestView review(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.beginReview(principal, id);
    }

    @PostMapping("/withdrawal-requests/{id}/approve")
    public WithdrawalRequestView approve(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.curatorApprove(principal, id);
    }

    @PostMapping("/withdrawal-requests/{id}/reject")
    public WithdrawalRequestView reject(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody ReasonRequest request) {
        return service.curatorReject(principal, id, request.reason());
    }

    @PostMapping("/withdrawal-requests/{id}/sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public WithdrawalSessionView plan(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                            @Valid @RequestBody WithdrawalSessionRequest request) {
        return service.planSession(principal, id, request.plannedDate());
    }

    @GetMapping("/withdrawal-sessions/{id}")
    public WithdrawalSessionView session(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.getSession(principal, id);
    }

    @PatchMapping("/withdrawal-sessions/{id}")
    public WithdrawalSessionView reschedule(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                  @Valid @RequestBody WithdrawalSessionRequest request) {
        return service.reschedule(principal, id, request.plannedDate());
    }

    @PostMapping("/withdrawal-sessions/{id}/complete")
    public WithdrawalSessionView complete(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.complete(principal, id);
    }
}
