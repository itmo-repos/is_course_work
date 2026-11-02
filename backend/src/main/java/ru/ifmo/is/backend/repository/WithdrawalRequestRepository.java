package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.WithdrawalRequest;
import ru.ifmo.is.backend.entitiy.enums.WithdrawalStatus;

import java.util.List;
import java.util.Optional;

public interface WithdrawalRequestRepository extends JpaRepository<WithdrawalRequest, Long> {
    List<WithdrawalRequest> findAllByDepositor_IdOrderBySubmittedAtDesc(Long depositorId);
    List<WithdrawalRequest> findAllByStatusOrderBySubmittedAtAsc(WithdrawalStatus status);
    List<WithdrawalRequest> findAllByOrderBySubmittedAtAsc();

    @Query("select r.batch.id from WithdrawalRequest r where r.id = :id")
    Optional<Long> findBatchIdById(@Param("id") Long id);

    @Query(value = """
            SELECT EXISTS (
                SELECT 1 FROM withdrawal_request_box rb
                JOIN withdrawal_request r ON r.id = rb.request_id
                WHERE rb.box_id IN (:boxIds)
                  AND r.status IN ('SUBMITTED', 'CURATOR_REVIEW', 'LEGAL_APPROVAL', 'APPROVED')
            )
            """, nativeQuery = true)
    boolean hasActiveRequestForBoxes(@Param("boxIds") List<Long> boxIds);
}
