package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.notification.NotificationView;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.repository.EmployeeRepository;
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
    private final EmployeeRepository employees;
    private final AuditService audit;

    @Transactional(propagation = Propagation.MANDATORY)
    public void depositor(Depositor depositor, AuditEvent event, NotificationType type) {
        Notification notification = business(event, type);
        notification.setDepositor(depositor);
        notifications.save(notification);
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void role(RoleCode role, AuditEvent event, NotificationType type) {
        for (Employee employee : employees.findActiveByRole(role)) {
            Notification notification = business(event, type);
            notification.setEmployee(employee);
            notifications.save(notification);
        }
    }

    private Notification business(AuditEvent event, NotificationType type) {
        Notification notification = new Notification();
        notification.setEvent(event);
        notification.setType(type);
        notification.setMessage(event.getMessage());
        return notification;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void climateAlert(ClimateReading reading, ClimateParameter parameter, String message) {
        for (Employee engineer : employees.findActiveByRole(RoleCode.ENGINEER)) {
            Notification notification = new Notification();
            notification.setEmployee(engineer);
            notification.setReading(reading);
            notification.setType(NotificationType.CLIMATE_ALERT);
            notification.setParameter(parameter);
            notification.setMessage(message);
            notifications.save(notification);
        }
    }

    public PageView<NotificationView> own(AuthPrincipal principal, boolean unreadOnly, int page, int size) {
        boolean staff = principal.type() == AuthPrincipal.AccountType.EMPLOYEE;
        if (staff) access.requireStaff(principal); else access.requireDepositor(principal);
        PageRequest paging = PageRequest.of(page, size);
        Page<Notification> result = notifications.own(staff ? principal.id() : null,
                staff ? null : principal.id(), unreadOnly, paging);
        return new PageView<>(result.map(this::view).getContent(), result.getTotalElements(), page, size);
    }

    @Transactional
    public NotificationView markRead(AuthPrincipal principal, Long id) {
        boolean staff = principal.type() == AuthPrincipal.AccountType.EMPLOYEE;
        if (staff) access.requireStaff(principal); else access.requireDepositor(principal);
        Notification notification = notifications.findByIdForUpdate(id).filter(n -> staff
                ? n.getEmployee() != null && n.getEmployee().getId().equals(principal.id())
                : n.getDepositor() != null && n.getDepositor().getId().equals(principal.id())).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Уведомление не найдено"));
        if (!notification.isRead()) {
            notification.setRead(true);
            audit.record(principal, "NOTIFICATION_READ", "NOTIFICATION", id, null, "Уведомление прочитано");
        }
        return view(notification);
    }

    private NotificationView view(Notification notification) {
        ClimateReading reading = notification.getReading();
        AuditEvent event = notification.getEvent();
        return new NotificationView(notification.getId(), reading == null ? null : reading.getId(),
                reading == null ? null : reading.getChamber().getId(), notification.getType(),
                notification.getParameter(), notification.getMessage(), notification.isRead(),
                notification.getCreatedAt().atOffset(ZoneOffset.UTC), event == null ? null : event.getId(),
                event == null ? null : event.getEntityType(), event == null ? null : event.getEntityId(),
                event == null ? null : event.getBatchId());
    }
}
