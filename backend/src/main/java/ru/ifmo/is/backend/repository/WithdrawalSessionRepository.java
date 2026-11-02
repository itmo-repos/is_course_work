package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.WithdrawalSession;

import java.util.Optional;

public interface WithdrawalSessionRepository extends JpaRepository<WithdrawalSession, Long> {
    Optional<WithdrawalSession> findByRequest_Id(Long requestId);
    boolean existsByRequest_Id(Long requestId);

    @Query("select s.request.batch.id from WithdrawalSession s where s.id = :id")
    Optional<Long> findBatchIdById(@Param("id") Long id);
}
