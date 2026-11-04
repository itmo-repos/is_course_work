package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.EmployeeRole;
import java.util.List;

public interface EmployeeRoleRepository extends JpaRepository<EmployeeRole, EmployeeRole.EmployeeRoleId> { // Указываем составной ключ
    List<EmployeeRole> findByEmployee_Id(Long employeeId);
}
