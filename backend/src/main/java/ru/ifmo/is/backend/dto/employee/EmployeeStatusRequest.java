package ru.ifmo.is.backend.dto.employee;

import jakarta.validation.constraints.NotNull;

public record EmployeeStatusRequest(@NotNull Boolean active) {}
