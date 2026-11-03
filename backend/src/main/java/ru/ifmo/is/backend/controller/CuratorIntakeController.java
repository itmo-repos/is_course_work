package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.batch.BatchIdentificationView;
import ru.ifmo.is.backend.dto.common.ReasonRequest;
import ru.ifmo.is.backend.dto.storage.ChamberMapView;
import ru.ifmo.is.backend.dto.storage.ChamberView;
import ru.ifmo.is.backend.dto.storage.IntakeSessionRequest;
import ru.ifmo.is.backend.dto.storage.IntakeSessionView;
import ru.ifmo.is.backend.dto.storage.StoragePlaceRequest;
import ru.ifmo.is.backend.dto.storage.StoragePlaceView;
import ru.ifmo.is.backend.dto.storage.StoredBoxView;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.ChamberMapService;
import ru.ifmo.is.backend.services.IntakeService;

import java.util.List;

@RestController
@RequestMapping("/api/curator")
@RequiredArgsConstructor
public class CuratorIntakeController {
    private final IntakeService service;
    private final ChamberMapService chamberMapService;

    @GetMapping("/batches/by-barcode/{barcode}")
    public BatchIdentificationView identify(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable String barcode) {
        return service.identify(principal, barcode);
    }

    @PostMapping("/batches/by-barcode/{barcode}/arrive")
    public BatchIdentificationView arrive(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable String barcode) {
        return service.arrive(principal, barcode);
    }

    @PostMapping("/batches/{id}/intake-sessions")
    @ResponseStatus(HttpStatus.CREATED)
    public IntakeSessionView create(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                               @Valid @RequestBody IntakeSessionRequest request) {
        return service.createSession(principal, id, request.chamberId(), request.plannedDate());
    }

    @PatchMapping("/intake-sessions/{id}")
    public IntakeSessionView update(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                              @Valid @RequestBody IntakeSessionRequest request) {
        return service.updateSession(principal, id, request.chamberId(), request.plannedDate());
    }

    @GetMapping("/intake-sessions/{id}")
    public IntakeSessionView session(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.getSession(principal, id);
    }

    @GetMapping("/chambers")
    public List<ChamberView> chambers(@AuthenticationPrincipal AuthPrincipal principal,
                                     @RequestParam(defaultValue = "false") boolean includeInactive) {
        return service.listChambers(principal, includeInactive);
    }

    @GetMapping("/chambers/{id}/places")
    public ChamberMapView places(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return chamberMapService.getMap(principal, id);
    }

    @GetMapping("/chambers/{id}/free-places")
    public List<StoragePlaceView> freePlaces(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.freePlaces(principal, id);
    }

    @PatchMapping("/boxes/{id}/storage-place")
    public StoredBoxView changePlace(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                     @Valid @RequestBody StoragePlaceRequest request) {
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
                              @Valid @RequestBody StoragePlaceRequest request) {
        return service.move(principal, id, request.storagePlaceId());
    }
}
