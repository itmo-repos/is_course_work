package ru.ifmo.is.backend.entitiy.enums;

public enum NotificationType {
    CLIMATE_ALERT,      // выход климата за допустимые границы
    WITHDRAWAL,         // события по заявкам на изъятие
    BATCH,              // события по партиям
    CONTRACT            // события по договорам и депозиторам
}
