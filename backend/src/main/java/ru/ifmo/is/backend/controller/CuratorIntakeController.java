package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.repository.projections.BatchBarcodeProjection;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.IntakeService;
import ru.ifmo.is.backend.services.IntakeService.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/curator")
@RequiredArgsConstructor
public class CuratorIntakeController {
    private final IntakeService service;

    @GetMapping("/batches/by-barcode/{barcode}")
    public BatchBarcodeProjection identify(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable String barcode) {
        return service.identify(principal, barcode);
    }

    @PostMapping("/batches/by-barcode/{barcode}/arrive")
    public BatchBarcodeProjection arrive(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable String barcode) {
        return service.arrive(principal, barcode);
    }

    @PostMapping("/batches/{id}/intake-sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public SessionView create(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                               @Valid @RequestBody SessionRequest request) {
        return service.createSession(principal, id, request.chamberId(), request.plannedDate());
    }

    @PatchMapping("/intake-sessions/{id}")
    public SessionView update(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody SessionRequest request) {
        return service.updateSession(principal, id, request.chamberId(), request.plannedDate());
    }

    @GetMapping("/intake-sessions/{id}")
    public SessionView session(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.getSession(principal, id);
    }

    @GetMapping("/chambers")
    public List<ChamberView> chambers(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.activeChambers(principal);
    }

    @GetMapping("/chambers/{id}/free-places")
    public List<PlaceView> freePlaces(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.freePlaces(principal, id);
    }

    @PatchMapping("/boxes/{id}/storage-place")
    public StoredBoxView changePlace(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                     @Valid @RequestBody PlaceRequest request) {
        return service.changePlace(principal, id, request.storagePlaceId());
    }

    @PostMapping("/boxes/{id}/place")
    public StoredBoxView place(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.place(principal, id);
    }

    @PostMapping("/boxes/{id}/write-off")
    public StoredBoxView writeOff(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                  @Valid @RequestBody ReasonRequest request) {
        return service.writeOff(principal, id, request.reason());
    }

    @PostMapping("/boxes/{id}/move")
    public StoredBoxView move(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody PlaceRequest request) {
        return service.move(principal, id, request.storagePlaceId());
    }

    public record SessionRequest(@NotNull @Positive Long chamberId, @NotNull @FutureOrPresent LocalDate plannedDate) {}
    public record PlaceRequest(@NotNull @Positive Long storagePlaceId) {}
    public record ReasonRequest(@NotBlank @Size(max = 2000) String reason) {}
}
