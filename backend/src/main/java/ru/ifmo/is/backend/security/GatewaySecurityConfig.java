package ru.ifmo.is.backend.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class GatewaySecurityConfig {
    @Bean
    @Order(1)
    SecurityFilterChain gatewaySecurityFilterChain(HttpSecurity http) throws Exception {
        http.securityMatcher("/api/gateway/**")
                .csrf(csrf -> csrf.disable())
                .securityContext(context -> context.disable())
                .requestCache(cache -> cache.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(authorize -> authorize
                        // Проверка хеша ключа выполняется в транзакции записи показания.
                        // В Spring Security ключ не создаёт пользователя и не даёт ему полномочий.
                        .requestMatchers(HttpMethod.POST, "/api/gateway/readings").permitAll()
                        .anyRequest().denyAll())
                .exceptionHandling(errors -> errors
                        .authenticationEntryPoint((request, response, exception) -> response.sendError(401)))
                .formLogin(form -> form.disable())
                .httpBasic(basic -> basic.disable())
                .logout(logout -> logout.disable());
        return http.build();
    }
}
