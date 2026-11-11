package ru.ifmo.is.backend.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import ru.ifmo.is.backend.entitiy.Notification;

import java.util.Optional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select n from Notification n where n.id = :id")
    Optional<Notification> findByIdForUpdate(Long id);
    @Query("""
            select n from Notification n where
            ((:employeeId is not null and n.employee.id = :employeeId)
             or (:depositorId is not null and n.depositor.id = :depositorId))
            and (:unreadOnly = false or n.read = false)
            order by n.createdAt desc, n.id desc
            """)
    Page<Notification> own(Long employeeId, Long depositorId, boolean unreadOnly, Pageable pageable);
    Page<Notification> findByEmployee_IdOrderByCreatedAtDescIdDesc(Long employeeId, Pageable pageable);

    Page<Notification> findByEmployee_IdAndReadFalseOrderByCreatedAtDescIdDesc(Long employeeId, Pageable pageable);

    Optional<Notification> findByIdAndEmployee_Id(Long id, Long employeeId);
}
