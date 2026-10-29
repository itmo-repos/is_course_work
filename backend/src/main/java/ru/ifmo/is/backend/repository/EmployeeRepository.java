package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Employee;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {

    @Query(value = "SELECT has_role(:employeeId, :roleCode)", nativeQuery = true)
    boolean hasRole(@Param("employeeId") Long employeeId, @Param("roleCode") String roleCode);

}
