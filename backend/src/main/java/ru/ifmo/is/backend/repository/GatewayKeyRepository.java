package ru.ifmo.is.backend.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.GatewayKey;

import java.util.List;
import java.util.Optional;

public interface GatewayKeyRepository extends JpaRepository<GatewayKey, Long> {
    List<GatewayKey> findAllByChamber_IdOrderByIssuedAtDescIdDesc(Long chamberId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select k from GatewayKey k where k.id = :id")
    Optional<GatewayKey> findByIdForUpdate(@Param("id") Long id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select k from GatewayKey k where k.keyHash = :hash")
    Optional<GatewayKey> findByHashForUpdate(@Param("hash") String hash);
}
