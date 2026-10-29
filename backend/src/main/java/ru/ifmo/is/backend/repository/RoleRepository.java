package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import ru.ifmo.is.backend.entitiy.Role;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;

public interface RoleRepository extends JpaRepository<Role, RoleCode> {
}
