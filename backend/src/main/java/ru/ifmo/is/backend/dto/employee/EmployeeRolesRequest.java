package ru.ifmo.is.backend.dto.employee;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import java.util.Set;

public record EmployeeRolesRequest(@NotNull @Size(max = 4) Set<@NotNull RoleCode> roles) {}
