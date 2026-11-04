package ru.ifmo.is.backend.dto.employee;

import ru.ifmo.is.backend.entitiy.enums.RoleCode;

public record RoleView(RoleCode code, String name, String description) {}
