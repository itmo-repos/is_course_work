package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import ru.ifmo.is.backend.dto.common.StoredDocument;
import ru.ifmo.is.backend.dto.depositor.ApplicationRequest;
import ru.ifmo.is.backend.dto.depositor.DepositorView;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.DepositorOnboardingService;

@RestController
@RequestMapping("/api/depositors")
@RequiredArgsConstructor
public class DepositorController {
    private final DepositorOnboardingService onboardingService;

    @PostMapping(path = "/applications", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<DepositorView> submitApplication(@Valid @RequestBody ApplicationRequest request) {
        DepositorView application = onboardingService.submitApplication(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(application);
    }

    @GetMapping("/me")
    public DepositorView myApplication(@AuthenticationPrincipal AuthPrincipal principal) {
        return onboardingService.getOwnProfile(principal);
    }

    @GetMapping("/me/contract")
    public ResponseEntity<byte[]> contractTemplate(@AuthenticationPrincipal AuthPrincipal principal) {
        return asDownload(onboardingService.getOwnContract(principal));
    }

    @PostMapping(path = "/me/contract/scan", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public DepositorView uploadSignedContract(@AuthenticationPrincipal AuthPrincipal principal,
                                              @RequestPart("file") MultipartFile file) {
        return onboardingService.uploadSignedContract(principal, file);
    }

    private static ResponseEntity<byte[]> asDownload(StoredDocument document) {
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(document.mediaType()))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(document.filename()).build().toString())
                .body(document.content());
    }
}
