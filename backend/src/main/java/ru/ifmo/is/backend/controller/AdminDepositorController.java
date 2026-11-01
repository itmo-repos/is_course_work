package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
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
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.DepositorOnboardingService;
import ru.ifmo.is.backend.services.DepositorOnboardingService.DepositorView;
import ru.ifmo.is.backend.services.DepositorOnboardingService.StoredDocument;

import java.util.List;

@RestController
@RequestMapping("/api/admin/depositors")
@RequiredArgsConstructor
public class AdminDepositorController {
    private final DepositorOnboardingService onboardingService;

    @GetMapping
    public List<DepositorView> applications(@RequestParam(required = false) DepositorStatus status) {
        return onboardingService.listApplications(status);
    }

    @PostMapping("/{id}/approve")
    public DepositorView approve(@PathVariable Long id) {
        return onboardingService.approveApplication(id);
    }

    @PostMapping("/{id}/reject")
    public DepositorView reject(@PathVariable Long id, @Valid @RequestBody RejectionRequest request) {
        return onboardingService.rejectApplication(id, request.reason());
    }

    @GetMapping("/{id}/contract/scan")
    public ResponseEntity<byte[]> signedScan(@PathVariable Long id) {
        return asDownload(onboardingService.getSignedScan(id));
    }

    @PostMapping("/{id}/contract/verify")
    public DepositorView verify(@PathVariable Long id, @AuthenticationPrincipal AuthPrincipal reviewer) {
        return onboardingService.verifyContract(id, reviewer);
    }

    @PostMapping("/{id}/contract/reject")
    public DepositorView rejectContract(@PathVariable Long id,
                                        @Valid @RequestBody RejectionRequest request) {
        return onboardingService.rejectContract(id, request.reason());
    }

    @PostMapping("/{id}/contract/return-for-signing")
    public DepositorView returnForSigning(@PathVariable Long id) {
        return onboardingService.returnForResubmission(id);
    }

    @PostMapping("/{id}/reject-final")
    public DepositorView rejectFinally(@PathVariable Long id,
                                       @Valid @RequestBody RejectionRequest request) {
        return onboardingService.rejectFinally(id, request.reason());
    }

    private static ResponseEntity<byte[]> asDownload(StoredDocument document) {
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(document.mediaType()))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(document.filename()).build().toString())
                .body(document.content());
    }

    public record RejectionRequest(@NotBlank @Size(max = 2000) String reason) {}
}
