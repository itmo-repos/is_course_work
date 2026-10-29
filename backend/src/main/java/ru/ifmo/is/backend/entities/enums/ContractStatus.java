package ru.ifmo.is.backend.entities.enums;

public enum ContractStatus {
    GENERATED,          // типовой договор сформирован системой
    SCAN_UPLOADED,      // загружен скан подписанного договора
    VERIFIED,           // верифицирован администратором
    REJECTED,           // отклонен администратором
    TERMINATED          // расторгнут
}
