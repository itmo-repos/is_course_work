package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.WithdrawalService;
import ru.ifmo.is.backend.services.WithdrawalService.RequestView;
import ru.ifmo.is.backend.services.WithdrawalService.SessionView;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/curator")
@RequiredArgsConstructor
public class CuratorWithdrawalController {
    private final WithdrawalService service;

    @GetMapping("/withdrawal-requests")
    public List<RequestView> list(@AuthenticationPrincipal AuthPrincipal principal,
                                  @RequestParam(required = false) WithdrawalStatus status) {
        return service.curatorRequests(principal, status);
    }

    @GetMapping("/withdrawal-requests/{id}")
    public RequestView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.curatorRequest(principal, id);
    }

    @PostMapping("/withdrawal-requests/{id}/review")
    public RequestView review(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.beginReview(principal, id);
    }

    @PostMapping("/withdrawal-requests/{id}/approve")
    public RequestView approve(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.curatorApprove(principal, id);
    }

    @PostMapping("/withdrawal-requests/{id}/reject")
    public RequestView reject(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody ReasonRequest request) {
        return service.curatorReject(principal, id, request.reason());
    }

    @PostMapping("/withdrawal-requests/{id}/sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public SessionView plan(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                            @Valid @RequestBody DateRequest request) {
        return service.planSession(principal, id, request.plannedDate());
    }

    @GetMapping("/withdrawal-sessions/{id}")
    public SessionView session(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.getSession(principal, id);
    }

    @PatchMapping("/withdrawal-sessions/{id}")
    public SessionView reschedule(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                  @Valid @RequestBody DateRequest request) {
        return service.reschedule(principal, id, request.plannedDate());
    }

    @PostMapping("/withdrawal-sessions/{id}/complete")
    public SessionView complete(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.complete(principal, id);
    }

    public record ReasonRequest(@NotBlank @Size(max = 2000) String reason) {}
    public record DateRequest(@NotNull @FutureOrPresent LocalDate plannedDate) {}
}
