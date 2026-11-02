package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import ru.ifmo.is.backend.entitiy.StoragePlace;

import java.util.List;
import java.util.Optional;

public interface StoragePlaceRepository extends JpaRepository<StoragePlace, Long> {
    @Query(value = """
            SELECT sp.* FROM storage_place sp
            WHERE sp.chamber_id = :chamberId AND sp.is_serviceable
              AND NOT EXISTS (SELECT 1 FROM box b WHERE b.storage_place_id = sp.id)
            ORDER BY sp.rack_no, sp.shelf_no, sp.row_no
            """, nativeQuery = true)
    List<StoragePlace> findFreePlaces(@Param("chamberId") Long chamberId);

    @Query(value = """
            SELECT sp.* FROM storage_place sp
            WHERE sp.chamber_id = :chamberId AND sp.is_serviceable
              AND NOT EXISTS (SELECT 1 FROM box b WHERE b.storage_place_id = sp.id)
            ORDER BY sp.rack_no, sp.shelf_no, sp.row_no
            LIMIT :count FOR UPDATE OF sp SKIP LOCKED
            """, nativeQuery = true)
    List<StoragePlace> reserveFreePlaces(@Param("chamberId") Long chamberId, @Param("count") int count);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from StoragePlace p where p.id = :id")
    Optional<StoragePlace> findByIdForUpdate(@Param("id") Long id);
}
