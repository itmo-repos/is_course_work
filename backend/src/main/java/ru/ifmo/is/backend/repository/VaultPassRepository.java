package ru.ifmo.is.backend.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import ru.ifmo.is.backend.entitiy.VaultPass;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface VaultPassRepository extends JpaRepository<VaultPass, Long> {
    Page<VaultPass> findAllByOrderByIdDesc(Pageable pageable);
    List<VaultPass> findByIntakeSession_IdOrderByIdAsc(Long sessionId);
    Optional<VaultPass> findByCodeHash(String codeHash);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from VaultPass p where p.id = :id")
    Optional<VaultPass> findByIdForUpdate(Long id);
    @Modifying
    @Query(value = "update vault_pass set status = 'EXPIRED' where status = 'ACTIVE' and valid_to <= :now", nativeQuery = true)
    int expire(LocalDateTime now);
}
