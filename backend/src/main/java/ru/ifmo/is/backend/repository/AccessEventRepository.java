package ru.ifmo.is.backend.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import ru.ifmo.is.backend.entitiy.AccessEvent;
import java.time.LocalDateTime;

public interface AccessEventRepository extends JpaRepository<AccessEvent, Long> {
    @Query("""
            select e from AccessEvent e where
            (:passId is null or e.pass.id = :passId) and
            (:employeeId is null or e.employee.id = :employeeId) and
            (:chamberId is null or e.chamber.id = :chamberId) and
            e.occurredAt between :from and :to order by e.occurredAt desc, e.id desc
            """)
    Page<AccessEvent> history(Long passId, Long employeeId, Long chamberId,
                              LocalDateTime from, LocalDateTime to, Pageable pageable);
}
