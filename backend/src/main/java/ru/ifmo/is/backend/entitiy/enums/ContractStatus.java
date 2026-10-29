package ru.ifmo.is.backend.entitiy.enums;

public enum ContractStatus {
    GENERATED,          // типовой договор сформирован системой
    SCAN_UPLOADED,      // загружен скан подписанного договора
    VERIFIED,           // верифицирован администратором
    REJECTED,           // отклонен администратором
    TERMINATED          // расторгнут
}
