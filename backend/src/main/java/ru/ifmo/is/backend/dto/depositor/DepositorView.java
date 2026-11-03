package ru.ifmo.is.backend.dto.depositor;

import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;

import java.time.OffsetDateTime;

public record DepositorView(
        Long id,
        String legalName,
        String countryCode,
        String countryName,
        String registrationNumber,
        String legalAddress,
        String contactPerson,
        String contactEmail,
        String contactPhone,
        DepositorStatus status,
        String rejectionReason,
        OffsetDateTime createdAt,
        ContractView contract
) {}
