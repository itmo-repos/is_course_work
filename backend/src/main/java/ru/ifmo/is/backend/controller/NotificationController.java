package ru.ifmo.is.backend.controller;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.notification.NotificationView;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.NotificationService;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {
    private final NotificationService service;

    @GetMapping
    public PageView<NotificationView> own(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(defaultValue = "false") boolean unreadOnly,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "100") @Min(1) @Max(200) int size) {
        return service.own(principal, unreadOnly, page, size);
    }

    @PatchMapping("/{id}/read")
    public NotificationView read(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.markRead(principal, id);
    }
}
