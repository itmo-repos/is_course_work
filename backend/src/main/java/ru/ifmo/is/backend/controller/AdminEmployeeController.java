package ru.ifmo.is.backend.controller;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import ru.ifmo.is.backend.dto.common.PageView;
import ru.ifmo.is.backend.dto.employee.*;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.services.EmployeeService;
import java.util.List;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminEmployeeController {
    private final EmployeeService service;

    @GetMapping("/employees")
    public PageView<EmployeeView> list(@AuthenticationPrincipal AuthPrincipal principal,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int size) {
        return service.list(principal, page, size);
    }

    @GetMapping("/employees/{id}")
    public EmployeeView get(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id) {
        return service.get(principal, id);
    }

    @GetMapping("/roles")
    public List<RoleView> roles(@AuthenticationPrincipal AuthPrincipal principal) {
        return service.roles(principal);
    }

    @PutMapping("/employees/{id}/roles")
    public EmployeeView roles(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                               @Valid @RequestBody EmployeeRolesRequest request) {
        return service.replaceRoles(principal, id, request.roles());
    }

    @PatchMapping("/employees/{id}/status")
    public EmployeeView status(@AuthenticationPrincipal AuthPrincipal principal, @PathVariable Long id,
                                @Valid @RequestBody EmployeeStatusRequest request) {
        return service.changeStatus(principal, id, request.active());
    }
}
