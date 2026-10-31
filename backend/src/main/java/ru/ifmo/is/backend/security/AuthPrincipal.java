package ru.ifmo.is.backend.security;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

public record AuthPrincipal(Long id, AccountType type, String email, List<String> roles)
        implements UserDetails {
    public enum AccountType { EMPLOYEE, DEPOSITOR }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        if (type == AccountType.DEPOSITOR) {
            return List.of(new SimpleGrantedAuthority("ROLE_DEPOSITOR"));
        }
        return roles.stream().map(role -> new SimpleGrantedAuthority("ROLE_" + role)).toList();
    }

    @Override public String getPassword() { return ""; }
    @Override public String getUsername() { return type + ":" + id; }
    @Override public boolean isAccountNonExpired() { return true; }
    @Override public boolean isAccountNonLocked() { return true; }
    @Override public boolean isCredentialsNonExpired() { return true; }
    @Override public boolean isEnabled() { return true; }
}
