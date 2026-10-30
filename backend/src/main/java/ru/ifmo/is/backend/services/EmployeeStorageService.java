package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.Role;
import ru.ifmo.is.backend.repository.EmployeeRepository;

@Service
@RequiredArgsConstructor
public class EmployeeStorageService {
    private final EmployeeRepository repository;

    public boolean hasRole(Employee employee, Role role) {
        return repository.hasRole(employee.getId(), role.getCode().name());
    }

}
