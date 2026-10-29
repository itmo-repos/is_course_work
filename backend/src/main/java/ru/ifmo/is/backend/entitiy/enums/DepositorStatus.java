package ru.ifmo.is.backend.entitiy.enums;

public enum DepositorStatus {
    NEW_REQUEST,        // новая заявка
    AWAITING_CONTRACT,  // ожидает подписания договора
    VERIFICATION,       // на верификации
    CONTRACT_REJECTED,  // договор отклонен
    ACTIVE,             // активен
    REJECTED            // отклонен окончательно
}
