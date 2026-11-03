package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.notification.NotificationView;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.repository.NotificationRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;

import java.time.ZoneOffset;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationService {
    private final NotificationRepository notifications;
    private final AccessService access;

    public PageView<NotificationView> own(AuthPrincipal principal, boolean unreadOnly, int page, int size) {
        Employee employee = access.requireStaff(principal);
        PageRequest paging = PageRequest.of(page, size);
        Page<Notification> result = unreadOnly
                ? notifications.findByEmployee_IdAndReadFalseOrderByCreatedAtDescIdDesc(employee.getId(), paging)
                : notifications.findByEmployee_IdOrderByCreatedAtDescIdDesc(employee.getId(), paging);
        return new PageView<>(result.map(this::view).getContent(), result.getTotalElements(), page, size);
    }

    @Transactional
    public NotificationView markRead(AuthPrincipal principal, Long id) {
        Employee employee = access.requireStaff(principal);
        Notification notification = notifications.findByIdAndEmployee_Id(id, employee.getId()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Уведомление не найдено"));
        notification.setRead(true);
        return view(notification);
    }

    private NotificationView view(Notification notification) {
        ClimateReading reading = notification.getReading();
        return new NotificationView(notification.getId(), reading == null ? null : reading.getId(),
                reading == null ? null : reading.getChamber().getId(), notification.getType(),
                notification.getParameter(), notification.getMessage(), notification.isRead(),
                notification.getCreatedAt().atOffset(ZoneOffset.UTC));
    }
}
