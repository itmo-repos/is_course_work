package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.DepositorOnboardingService;
import ru.ifmo.is.backend.services.DepositorOnboardingService.DepositorView;
import ru.ifmo.is.backend.services.DepositorOnboardingService.StoredDocument;

@RestController
@RequestMapping("/api/depositors")
@RequiredArgsConstructor
public class DepositorController {
    private final DepositorOnboardingService onboardingService;

    @PostMapping(path = "/applications", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<DepositorView> submitApplication(@Valid @RequestBody ApplicationRequest request) {
        DepositorView application = onboardingService.submitApplication(new DepositorOnboardingService.ApplicationData(
                request.legalName(), request.countryCode(), request.registrationNumber(), request.legalAddress(),
                request.contactPerson(), request.contactEmail(), request.contactPhone(), request.password()));
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

    public record ApplicationRequest(
            @NotBlank @Size(max = 300) String legalName,
            @NotBlank @Pattern(regexp = "^[A-Za-z]{2}$") String countryCode,
            @NotBlank @Size(max = 64) String registrationNumber,
            @NotBlank @Size(max = 5000) String legalAddress,
            @NotBlank @Size(max = 200) String contactPerson,
            @NotBlank @Email @Size(max = 254) String contactEmail,
            @Size(max = 32) String contactPhone,
            @NotBlank @Size(min = 8, max = 128) String password) {}
}
