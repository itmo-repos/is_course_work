package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.pass.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.AccessJournalService;
import ru.ifmo.is.backend.services.VaultPassService;
import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/security")
@RequiredArgsConstructor
public class SecurityAccessController {
    private final VaultPassService passes;
    private final AccessJournalService journal;

    @PostMapping("/passes") @ResponseStatus(HttpStatus.CREATED)
    public ResponseEntity<IssuedPass> issue(@AuthenticationPrincipal AuthPrincipal principal, @Valid @RequestBody PassRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).cacheControl(CacheControl.noStore()).body(passes.issue(principal, request));
    }

    @GetMapping("/passes")
    public PageView<PassView> list(@AuthenticationPrincipal AuthPrincipal principal,
                                  @RequestParam(defaultValue = "0") @Min(0) int page,
                                  @RequestParam(defaultValue = "50") @Min(1) @Max(200) int size) {
        return passes.list(principal, page, size);
    }

    @GetMapping("/passes/{id}")
    public PassView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return passes.get(principal, id);
    }

    @PostMapping("/passes/{id}/revoke")
    public PassView revoke(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return passes.revoke(principal, id);
    }

    @PostMapping("/access-events") @ResponseStatus(HttpStatus.CREATED)
    public AccessEventView record(@AuthenticationPrincipal AuthPrincipal principal,
                                   @Valid @RequestBody AccessEventRequest request) {
        return journal.record(principal, request);
    }

    @GetMapping("/access-events")
    public PageView<AccessEventView> history(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(required = false) @Positive Long passId,
            @RequestParam(required = false) @Positive Long employeeId,
            @RequestParam(required = false) @Positive Long chamberId,
            @RequestParam OffsetDateTime from, @RequestParam OffsetDateTime to,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int size) {
        return journal.history(principal, passId, employeeId, chamberId, from, to, page, size);
    }
}
