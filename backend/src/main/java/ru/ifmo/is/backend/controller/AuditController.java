package ru.ifmo.is.backend.controller;

import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.audit.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.HistoryService;
import java.time.OffsetDateTime;

@RestController
@RequiredArgsConstructor
public class AuditController {
    private final HistoryService service;

    @GetMapping("/api/admin/audit")
    public PageView<AuditView> audit(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(required = false) @Pattern(regexp = "EMPLOYEE|DEPOSITOR|GUEST|GATEWAY|SYSTEM") String actorType,
            @RequestParam(required = false) @Positive Long actorId,
            @RequestParam(required = false) @Size(max = 80) String action,
            @RequestParam(required = false) @Size(max = 40) String entityType,
            @RequestParam(required = false) @Positive Long entityId,
            @RequestParam(required = false) @Positive Long batchId,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int size) {
        return service.audit(principal, from, to, actorType, actorId, action, entityType, entityId, batchId, page, size);
    }

    @GetMapping({"/api/curator/batches/{id}/history", "/api/admin/batches/{id}/history"})
    public PageView<BatchHistoryView> batch(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int size) {
        return service.batch(principal, id, page, size);
    }

    @GetMapping("/api/depositors/me/batches/{id}/history")
    public PageView<BatchHistoryView> own(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int size) {
        return service.ownBatch(principal, id, page, size);
    }
}
