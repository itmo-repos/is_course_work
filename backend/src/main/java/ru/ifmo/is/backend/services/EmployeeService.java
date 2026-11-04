package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.employee.*;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.EmployeeRole;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.*;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EmployeeService {
    private final EmployeeRepository employees;
    private final EmployeeRoleRepository assignments;
    private final RoleRepository roles;
    private final AccessService access;

    public PageView<EmployeeView> list(AuthPrincipal principal, int page, int size) {
        access.requireRole(principal, RoleCode.ADMIN);
        var result = employees.findAllByOrderByFullNameAscIdAsc(PageRequest.of(page, size));
        return new PageView<>(result.map(this::view).getContent(), result.getTotalElements(), page, size);
    }

    public EmployeeView get(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.ADMIN);
        return view(employees.findById(id).orElseThrow(this::notFound));
    }

    public List<RoleView> roles(AuthPrincipal principal) {
        access.requireRole(principal, RoleCode.ADMIN);
        return roles.findAllByOrderByCodeAsc().stream()
                .map(role -> new RoleView(role.getCode(), role.getName(), role.getDescription())).toList();
    }

    @Transactional
    public EmployeeView replaceRoles(AuthPrincipal principal, Long id, Set<RoleCode> requested) {
        Employee employee = lockForChange(principal, id);
        keepActiveAdmin(employee, employee.isActive() && requested.contains(RoleCode.ADMIN));
        Employee actor = access.requireStaff(principal);
        List<EmployeeRole> current = assignments.findByEmployee_Id(id);
        for (EmployeeRole assignment : current) {
            if (!requested.contains(assignment.getRole().getCode())) assignments.delete(assignment);
        }
        for (RoleCode code : requested) {
            boolean alreadyAssigned = current.stream().anyMatch(assignment -> assignment.getRole().getCode() == code);
            if (alreadyAssigned) continue;
            EmployeeRole assignment = new EmployeeRole();
            assignment.setEmployeeRoleId(new EmployeeRole.EmployeeRoleId(id, code));
            assignment.setEmployee(employee);
            assignment.setRole(roles.findById(code).orElseThrow(() ->
                    new ResponseStatusException(HttpStatus.NOT_FOUND, "Роль не найдена")));
            assignment.setAssignedBy(actor);
            assignments.save(assignment);
        }
        assignments.flush();
        return view(employee);
    }

    @Transactional
    public EmployeeView changeStatus(AuthPrincipal principal, Long id, boolean active) {
        Employee employee = lockForChange(principal, id);
        keepActiveAdmin(employee, active && employees.findRoleCodes(id).contains(RoleCode.ADMIN));
        if (employee.isActive() && !active) employee.setSessionVersion(employee.getSessionVersion() + 1);
        employee.setActive(active);
        return view(employee);
    }

    private Employee lockForChange(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.ADMIN);
        // Одна общая блокировка делает проверку последнего администратора надёжной
        // даже при одновременном изменении разных сотрудников.
        roles.lockAdmin().orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT, "Роль ADMIN не настроена"));
        access.requireRole(principal, RoleCode.ADMIN);
        return employees.findByIdForUpdate(id).orElseThrow(this::notFound);
    }

    private void keepActiveAdmin(Employee employee, boolean willBeActiveAdmin) {
        boolean wasActiveAdmin = employee.isActive() && employees.findRoleCodes(employee.getId()).contains(RoleCode.ADMIN);
        if (wasActiveAdmin && !willBeActiveAdmin
                && employees.countOtherActiveByRole(RoleCode.ADMIN, employee.getId()) == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Должен остаться хотя бы один активный администратор");
        }
    }

    private EmployeeView view(Employee employee) {
        List<RoleCode> codes = employees.findRoleCodes(employee.getId()).stream().sorted().toList();
        return new EmployeeView(employee.getId(), employee.getFullName(), employee.getEmail(), employee.getPhone(),
                employee.getHiredAt(), employee.isActive(), codes);
    }

    private ResponseStatusException notFound() {
        return new ResponseStatusException(HttpStatus.NOT_FOUND, "Сотрудник не найден");
    }
}
