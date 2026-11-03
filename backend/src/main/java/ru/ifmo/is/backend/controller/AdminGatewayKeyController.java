package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.gateway.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.GatewayKeyService;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminGatewayKeyController {
    private final GatewayKeyService service;

    @PostMapping("/chambers/{id}/gateway-keys")
    public ResponseEntity<IssuedGatewayKey> issue(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                                @Valid @RequestBody GatewayKeyRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).cacheControl(CacheControl.noStore())
                .body(service.issue(principal, id, request.name()));
    }

    @GetMapping("/chambers/{id}/gateway-keys")
    public List<GatewayKeyView> list(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.list(principal, id);
    }

    @DeleteMapping("/gateway-keys/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        service.delete(principal, id);
    }
}
