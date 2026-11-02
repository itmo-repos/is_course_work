package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.entitiy.enums.BatchStatus;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.BatchService;
import ru.ifmo.is.backend.services.BatchService.BatchView;

import java.util.List;

@RestController
@RequestMapping("/api/curator/batches")
@RequiredArgsConstructor
public class CuratorBatchController {
    private final BatchService service;

    @GetMapping
    public List<BatchView> list(@AuthenticationPrincipal AuthPrincipal principal,
                                @RequestParam(required = false) BatchStatus status) {
        return service.curatorBatches(principal, status);
    }

    @GetMapping("/{id}")
    public BatchView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.curatorBatch(principal, id);
    }

    @PostMapping("/{id}/confirm")
    public BatchView confirm(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.confirm(principal, id);
    }

    @PostMapping("/{id}/reject")
    public BatchView reject(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                            @Valid @RequestBody RejectionRequest request) {
        return service.reject(principal, id, request.reason());
    }

    @PatchMapping("/{id}/tracking-status")
    public BatchView tracking(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody TrackingRequest request) {
        return service.tracking(principal, id, request.status(), request.trackingNumber());
    }

    public record RejectionRequest(@NotBlank @Size(max = 2000) String reason) {}
    public record TrackingRequest(@NotNull BatchStatus status, @Size(max = 64) String trackingNumber) {}
}
