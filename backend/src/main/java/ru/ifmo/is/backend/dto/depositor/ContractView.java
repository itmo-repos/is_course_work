package ru.ifmo.is.backend.dto.depositor;

import ru.ifmo.is.backend.entitiy.enums.ContractStatus;

public record ContractView(
        String number,
        ContractStatus status,
        String rejectionReason
) {}
