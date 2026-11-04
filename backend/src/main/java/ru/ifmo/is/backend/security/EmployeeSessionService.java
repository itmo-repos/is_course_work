package ru.ifmo.is.backend.security;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ru.ifmo.is.backend.repository.EmployeeRepository;

@Service
@RequiredArgsConstructor
public class EmployeeSessionService {
    private final EmployeeRepository employees;

    @Transactional(readOnly = true)
    public AuthPrincipal current(AuthPrincipal principal) {
        Long id = principal.id();
        var employee = employees.findById(id).filter(account -> account.isActive()
                && account.getSessionVersion() == principal.sessionVersion());
        if (employee.isEmpty()) return null;
        var account = employee.get();
        var roles = employees.findRoleCodes(id).stream().map(Enum::name).sorted().toList();
        return new AuthPrincipal(id, AuthPrincipal.AccountType.EMPLOYEE, account.getEmail(), roles, account.getSessionVersion());
    }
}
