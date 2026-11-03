package ru.ifmo.is.backend.dto.notification;

import ru.ifmo.is.backend.entitiy.enums.ClimateParameter;
import ru.ifmo.is.backend.entitiy.enums.NotificationType;
import java.time.OffsetDateTime;

public record NotificationView(Long id, Long readingId, Long chamberId, NotificationType type,
                               ClimateParameter parameter, String message, boolean read, OffsetDateTime createdAt) {}
