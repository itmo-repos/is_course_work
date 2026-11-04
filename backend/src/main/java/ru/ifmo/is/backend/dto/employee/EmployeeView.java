package ru.ifmo.is.backend.dto.employee;

import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import java.time.LocalDate;
import java.util.List;

public record EmployeeView(Long id, String fullName, String email, String phone,
                           LocalDate hiredAt, boolean active, List<RoleCode> roles) {}
