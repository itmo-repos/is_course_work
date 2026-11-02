package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.BatchService;
import ru.ifmo.is.backend.services.BatchService.BatchData;
import ru.ifmo.is.backend.services.BatchService.BatchView;

import java.util.List;

@RestController
@RequestMapping("/api/depositors/me/batches")
@RequiredArgsConstructor
public class DepositorBatchController {
    private final BatchService service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BatchView create(@AuthenticationPrincipal AuthPrincipal principal, @Valid @RequestBody BatchData data) {
        return service.create(principal, data);
    }

    @GetMapping
    public List<BatchView> list(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.ownBatches(principal);
    }

    @GetMapping("/{id}")
    public BatchView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.ownBatch(principal, id);
    }

    @PutMapping("/{id}")
    public BatchView resubmit(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody BatchData data) {
        return service.resubmit(principal, id, data);
    }

    @GetMapping(value = "/{id}/boxes/{boxId}/barcode", produces = "image/svg+xml")
    public ResponseEntity<String> barcode(@AuthenticationPrincipal AuthPrincipal principal,
                                          @PathVariable Long id, @PathVariable Long boxId) {
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_DISPOSITION,
                "attachment; filename=box-" + boxId + ".svg").body(service.barcode(principal, id, boxId));
    }
}
