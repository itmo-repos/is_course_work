package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import ru.ifmo.is.backend.entitiy.Role;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;

public interface RoleRepository extends JpaRepository<Role, RoleCode> {
    List<Role> findAllByOrderByCodeAsc();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from Role r where r.code = ru.ifmo.is.backend.entitiy.enums.RoleCode.ADMIN")
    Optional<Role> lockAdmin();
}
