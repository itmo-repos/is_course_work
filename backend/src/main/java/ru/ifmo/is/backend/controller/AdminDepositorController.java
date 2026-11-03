package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import ru.ifmo.is.backend.dto.common.ReasonRequest;
import ru.ifmo.is.backend.dto.common.StoredDocument;
import ru.ifmo.is.backend.dto.depositor.DepositorView;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.DepositorOnboardingService;

import java.util.List;

@RestController
@RequestMapping("/api/admin/depositors")
@RequiredArgsConstructor
public class AdminDepositorController {
    private final DepositorOnboardingService onboardingService;

    @GetMapping
    public List<DepositorView> applications(@AuthenticationPrincipal AuthPrincipal principal, @RequestParam(required = false) DepositorStatus status) {
        return onboardingService.listApplications(principal, status);
    }

    @PostMapping("/{id}/approve")
    public DepositorView approve(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return onboardingService.approveApplication(principal, id);
    }

    @PostMapping("/{id}/reject")
    public DepositorView reject(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id, @Valid @RequestBody ReasonRequest request) {
        return onboardingService.rejectApplication(principal, id, request.reason());
    }

    @GetMapping("/{id}/contract/scan")
    public ResponseEntity<byte[]> signedScan(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return asDownload(onboardingService.getSignedScan(principal, id));
    }

    @PostMapping("/{id}/contract/verify")
    public DepositorView verify(@PathVariable Long id, @AuthenticationPrincipal AuthPrincipal reviewer) {
        return onboardingService.verifyContract(id, reviewer);
    }

    @PostMapping("/{id}/contract/reject")
    public DepositorView rejectContract(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                        @Valid @RequestBody ReasonRequest request) {
        return onboardingService.rejectContract(principal, id, request.reason());
    }

    @PostMapping("/{id}/contract/return-for-signing")
    public DepositorView returnForSigning(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return onboardingService.returnForResubmission(principal, id);
    }

    @PostMapping("/{id}/reject-final")
    public DepositorView rejectFinally(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                       @Valid @RequestBody ReasonRequest request) {
        return onboardingService.rejectFinally(principal, id, request.reason());
    }

    private static ResponseEntity<byte[]> asDownload(StoredDocument document) {
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(document.mediaType()))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(document.filename()).build().toString())
                .body(document.content());
    }
}
