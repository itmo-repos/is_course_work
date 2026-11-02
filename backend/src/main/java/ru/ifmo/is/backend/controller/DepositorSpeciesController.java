package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.SpeciesService;
import ru.ifmo.is.backend.services.SpeciesService.SpeciesView;

@RestController
@RequestMapping("/api/depositors/me/species")
@RequiredArgsConstructor
public class DepositorSpeciesController {
    private final SpeciesService service;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SpeciesView create(@AuthenticationPrincipal AuthPrincipal principal,
                               @Valid @RequestBody SpeciesRequest request) {
        return service.create(principal, request.latinName(), request.localName(), request.family());
    }

    public record SpeciesRequest(@NotBlank @Size(max = 160) String latinName,
                                 @NotBlank @Size(max = 160) String localName,
                                 @Size(max = 120) String family) {}
}
