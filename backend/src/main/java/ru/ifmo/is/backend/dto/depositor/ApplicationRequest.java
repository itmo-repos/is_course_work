package ru.ifmo.is.backend.dto.depositor;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ApplicationRequest(
        @NotBlank @Size(max = 300) String legalName,
        @NotBlank @Pattern(regexp = "^[A-Za-z]{2}$") String countryCode,
        @NotBlank @Size(max = 64) String registrationNumber,
        @NotBlank @Size(max = 5000) String legalAddress,
        @NotBlank @Size(max = 200) String contactPerson,
        @NotBlank @Email @Size(max = 254) String contactEmail,
        @Size(max = 32) String contactPhone,
        @NotBlank @Size(min = 8, max = 128) String password
) {}
