package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.WithdrawalService;
import ru.ifmo.is.backend.services.WithdrawalService.RequestView;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/depositors/me/withdrawal-requests")
@RequiredArgsConstructor
public class DepositorWithdrawalController {
    private final WithdrawalService service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public RequestView submit(@AuthenticationPrincipal AuthPrincipal principal, @Valid @RequestBody RequestData request) {
        return service.submit(principal, request.batchId(), request.boxIds(), request.reason(), request.desiredDate());
    }

    @GetMapping
    public List<RequestView> list(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.ownRequests(principal);
    }

    @GetMapping("/{id}")
    public RequestView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.ownRequest(principal, id);
    }

    public record RequestData(@NotNull @Positive Long batchId,
                              @NotEmpty @Size(max = 100) List<@NotNull @Positive Long> boxIds,
                              @NotBlank @Size(max = 2000) String reason,
                              @NotNull @FutureOrPresent LocalDate desiredDate) {}
}
