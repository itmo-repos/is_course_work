package ru.ifmo.is.backend.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import ru.ifmo.is.backend.entitiy.AuditEvent;
import java.time.LocalDateTime;

public interface AuditEventRepository extends JpaRepository<AuditEvent, Long> {
    @Query("""
            select e from AuditEvent e where e.occurredAt between :from and :to
              and (:actorType is null or e.actorType = :actorType)
              and (:actorId is null or e.actorId = :actorId)
              and (:action is null or e.action = :action)
              and (:entityType is null or e.entityType = :entityType)
              and (:entityId is null or e.entityId = :entityId)
              and (:batchId is null or e.batchId = :batchId)
            order by e.occurredAt desc, e.id desc
            """)
    Page<AuditEvent> search(LocalDateTime from, LocalDateTime to, String actorType, Long actorId,
                             String action, String entityType, Long entityId, Long batchId, Pageable pageable);

    Page<AuditEvent> findByBatchIdOrderByOccurredAtAscIdAsc(Long batchId, Pageable pageable);
}
