package ru.ifmo.is.backend.entities.enums;

public enum WithdrawalStatus {
    SUBMITTED,          // подана
    CURATOR_REVIEW,     // на проверке у курирующего сотрудника
    LEGAL_APPROVAL,     // на юридическом утверждении
    APPROVED,           // одобрена
    REJECTED,           // отклонена
    FULFILLED           // выполнена
}
