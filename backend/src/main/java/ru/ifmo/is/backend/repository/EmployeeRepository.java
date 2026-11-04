package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import jakarta.persistence.LockModeType;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;

import java.util.List;
import java.util.Optional;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    Page<Employee> findAllByOrderByFullNameAscIdAsc(Pageable pageable);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Employee e where e.id = :id")
    Optional<Employee> findByIdForUpdate(@Param("id") Long id);

    @Query("select count(er) from EmployeeRole er where er.role.code = :role and er.employee.isActive = true and er.employee.id <> :employeeId")
    long countOtherActiveByRole(@Param("role") RoleCode role, @Param("employeeId") Long employeeId);

    Optional<Employee> findByEmailIgnoreCase(String email);

    @Query("select er.role.code from EmployeeRole er where er.employee.id = :employeeId")
    List<RoleCode> findRoleCodes(@Param("employeeId") Long employeeId);

    @Query("select er.employee from EmployeeRole er where er.role.code = :role and er.employee.isActive = true")
    List<Employee> findActiveByRole(@Param("role") RoleCode role);

    @Query(value = "SELECT has_role(:employeeId, :roleCode)", nativeQuery = true)
    boolean hasRole(@Param("employeeId") Long employeeId, @Param("roleCode") String roleCode);

}
