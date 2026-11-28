package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import ru.ifmo.is.backend.entitiy.*;
import ru.ifmo.is.backend.entitiy.enums.*;
import ru.ifmo.is.backend.security.AuthPrincipal;

@Service
@RequiredArgsConstructor
@Transactional(propagation = Propagation.MANDATORY)
public class BusinessEventService {
    private final AuditService audit;
    private final NotificationService notifications;

    public void depositor(AuthPrincipal actor, Depositor depositor, String action, String message) {
        if (depositor.getRejectionReason() != null) message += ": " + depositor.getRejectionReason();
        AuditEvent event = audit.record(actor, action, "DEPOSITOR", depositor.getId(), null, message);
        if (action.equals("APPLICATION_SUBMITTED") || action.equals("APPLICATION_RESUBMITTED")
                || action.equals("CONTRACT_SCAN_UPLOADED")) {
            notifications.role(RoleCode.ADMIN, event, NotificationType.CONTRACT);
        } else {
            notifications.depositor(depositor, event, NotificationType.CONTRACT);
        }
    }

    public void batch(AuthPrincipal actor, Batch batch, String action, String message) {
        AuditEvent event = audit.record(actor, action, "BATCH", batch.getId(), batch.getId(), message);
        if (action.equals("BATCH_CREATED") || action.equals("BATCH_RESUBMITTED")) {
            notifications.role(RoleCode.CURATOR, event, NotificationType.BATCH);
        } else {
            notifications.depositor(batch.getDepositor(), event, NotificationType.BATCH);
        }
    }

    public void intake(AuthPrincipal actor, IntakeSession session, String action, String message) {
        AuditEvent event = audit.record(actor, action, "INTAKE_SESSION", session.getId(), session.getBatch().getId(), message,
                "chamberId=" + session.getChamber().getId() + "; plannedDate=" + session.getPlannedDate());
        notifications.depositor(session.getBatch().getDepositor(), event, NotificationType.BATCH);
    }

    public void box(AuthPrincipal actor, Box box, String action, String message) {
        AuditEvent event = audit.record(actor, action, "BOX", box.getId(), box.getBatch().getId(), message,
                "status=" + box.getStatus() + "; storagePlaceId="
                        + (box.getStoragePlace() == null ? null : box.getStoragePlace().getId()));
        notifications.depositor(box.getBatch().getDepositor(), event, NotificationType.BATCH);
    }

    public void withdrawal(AuthPrincipal actor, WithdrawalRequest request, String action, String message) {
        AuditEvent event = audit.record(actor, action, "WITHDRAWAL", request.getId(), request.getBatch().getId(), message);
        if (action.equals("WITHDRAWAL_SUBMITTED")) {
            notifications.role(RoleCode.CURATOR, event, NotificationType.WITHDRAWAL);
        } else {
            notifications.depositor(request.getDepositor(), event, NotificationType.WITHDRAWAL);
            if (action.equals("WITHDRAWAL_LEGAL_APPROVAL")) {
                notifications.role(RoleCode.ADMIN, event, NotificationType.WITHDRAWAL);
            }
        }
    }
}
