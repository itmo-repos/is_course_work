package ru.ifmo.is.backend.security;

import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import ru.ifmo.is.backend.entitiy.Depositor;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.enums.DepositorStatus;
import ru.ifmo.is.backend.repository.DepositorRepository;
import ru.ifmo.is.backend.repository.EmployeeRepository;

import java.util.List;

@Component
@RequiredArgsConstructor
public class AccountAuthenticationProvider implements AuthenticationProvider {
    private final EmployeeRepository employeeRepository;
    private final DepositorRepository depositorRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public Authentication authenticate(Authentication authentication) throws AuthenticationException {
        String email = authentication.getName().strip();
        String password = String.valueOf(authentication.getCredentials());
        var employee = employeeRepository.findByEmailIgnoreCase(email);
        var depositor = depositorRepository.findByContactEmailIgnoreCase(email);

        if (employee.isPresent() && depositor.isPresent()) {
            throw new BadCredentialsException("Invalid email or password");
        }
        if (employee.isPresent()) {
            Employee account = employee.get();
            if (!account.isActive() || !passwordEncoder.matches(password, account.getPasswordHash())) {
                throw new BadCredentialsException("Invalid email or password");
            }
            List<String> roles = employeeRepository.findRoleCodes(account.getId()).stream()
                    .map(Enum::name).toList();
            AuthPrincipal principal = new AuthPrincipal(account.getId(), AuthPrincipal.AccountType.EMPLOYEE,
                    account.getEmail(), roles, account.getSessionVersion());
            return UsernamePasswordAuthenticationToken.authenticated(principal, null, principal.getAuthorities());
        }
        if (depositor.isPresent()) {
            Depositor account = depositor.get();
            if (account.getStatus() == DepositorStatus.REJECTED
                    || !passwordEncoder.matches(password, account.getPasswordHash())) {
                throw new BadCredentialsException("Invalid email or password");
            }
            AuthPrincipal principal = new AuthPrincipal(account.getId(), AuthPrincipal.AccountType.DEPOSITOR,
                    account.getContactEmail(), List.of(), 0);
            return UsernamePasswordAuthenticationToken.authenticated(principal, null, principal.getAuthorities());
        }
        throw new BadCredentialsException("Invalid email or password");
    }

    @Override
    public boolean supports(Class<?> authentication) {
        return UsernamePasswordAuthenticationToken.class.isAssignableFrom(authentication);
    }
}
