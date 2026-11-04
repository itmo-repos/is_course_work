package ru.ifmo.is.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;

@RequiredArgsConstructor
public class EmployeeSessionFilter extends OncePerRequestFilter {
    private final EmployeeSessionService employees;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        var authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication != null && authentication.getPrincipal() instanceof AuthPrincipal principal
                && principal.type() == AuthPrincipal.AccountType.EMPLOYEE) {
            AuthPrincipal current = employees.current(principal);
            if (current == null) {
                SecurityContextHolder.clearContext();
                var session = request.getSession(false);
                if (session != null) {
                    try {
                        session.invalidate();
                    } catch (IllegalStateException ignored) {
                        // Параллельный запрос мог уже закрыть эту же сессию.
                    }
                }
            } else {
                // Контекст новый для запроса: не меняем общий объект параллельных запросов сессии.
                var context = SecurityContextHolder.createEmptyContext();
                context.setAuthentication(UsernamePasswordAuthenticationToken.authenticated(
                        current, null, current.getAuthorities()));
                SecurityContextHolder.setContext(context);
            }
        }
        chain.doFilter(request, response);
    }
}
