package ru.ifmo.is.backend.services;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import ru.ifmo.is.backend.dto.gateway.*;
import ru.ifmo.is.backend.entitiy.Chamber;
import ru.ifmo.is.backend.entitiy.Employee;
import ru.ifmo.is.backend.entitiy.GatewayKey;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;
import ru.ifmo.is.backend.repository.ChamberRepository;
import ru.ifmo.is.backend.repository.GatewayKeyRepository;
import ru.ifmo.is.backend.security.AccessService;
import ru.ifmo.is.backend.security.AuthPrincipal;
import ru.ifmo.is.backend.security.GatewayKeyHasher;

import java.time.ZoneOffset;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GatewayKeyService {
    private final AuditService audit;
    private final GatewayKeyRepository keys;
    private final ChamberRepository chambers;
    private final AccessService access;
    private final GatewayKeyHasher hasher;

    @Transactional
    public IssuedGatewayKey issue(AuthPrincipal principal, Long chamberId, String name) {
        Employee admin = access.requireEmployee(principal, RoleCode.ADMIN);
        Chamber chamber = findChamber(chamberId);
        String token = hasher.generate();
        GatewayKey key = new GatewayKey();
        key.setName(name.strip());
        key.setChamber(chamber);
        key.setKeyHash(hasher.hash(token));
        key.setIssuedBy(admin);
        keys.save(key);
        // Сырой ключ возвращается только здесь; в БД сохраняется только его хеш.
        audit.record(principal, "GATEWAY_KEY_ISSUED", "GATEWAY_KEY", key.getId(), null, "Выдан ключ шлюза", "chamberId=" + chamberId);
        return new IssuedGatewayKey(view(key), token);
    }

    public List<GatewayKeyView> list(AuthPrincipal principal, Long chamberId) {
        access.requireRole(principal, RoleCode.ADMIN);
        findChamber(chamberId);
        return keys.findAllByChamber_IdOrderByIssuedAtDescIdDesc(chamberId).stream().map(this::view).toList();
    }

    @Transactional
    public void delete(AuthPrincipal principal, Long id) {
        access.requireRole(principal, RoleCode.ADMIN);
        GatewayKey key = keys.findByIdForUpdate(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Ключ шлюза не найден"));
        audit.record(principal, "GATEWAY_KEY_DELETED", "GATEWAY_KEY", id, null, "Удалён ключ шлюза", "chamberId=" + key.getChamber().getId());
        keys.delete(key);
    }

    private Chamber findChamber(Long id) {
        return chambers.findById(id).orElseThrow(() ->
                new ResponseStatusException(HttpStatus.NOT_FOUND, "Камера не найдена"));
    }

    private GatewayKeyView view(GatewayKey key) {
        return new GatewayKeyView(key.getId(), key.getName(), key.getChamber().getId(),
                key.getIssuedBy().getId(), key.getIssuedAt().atOffset(ZoneOffset.UTC));
    }
}
