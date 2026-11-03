package ru.ifmo.is.backend.security;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.EmployeeRepository;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AccessService {
    private final EmployeeRepository employees;

    public void requireDepositor(AuthPrincipal principal) {
        if (principal == null || principal.type() != AuthPrincipal.AccountType.DEPOSITOR) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Доступ только депозитору");
        }
    }

    public void requireRole(AuthPrincipal principal, RoleCode role) {
        // Проверяем текущую роль и активность в БД, а не снимок полномочий из сессии.
        if (principal == null || principal.type() != AuthPrincipal.AccountType.EMPLOYEE
                || !employees.hasRole(principal.id(), role.name())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Нужна роль " + role);
        }
    }

    public Employee requireEmployee(AuthPrincipal principal, RoleCode role) {
        requireRole(principal, role);
        return employees.findById(principal.id()).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.FORBIDDEN, "Сотрудник не найден"));
    }
}
