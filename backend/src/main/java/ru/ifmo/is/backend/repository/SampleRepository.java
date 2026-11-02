package ru.ifmo.is.backend.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ru.ifmo.is.backend.entitiy.Sample;
import ru.ifmo.is.backend.repository.projections.SampleSearchProjection;

import java.util.List;

public interface SampleRepository extends JpaRepository<Sample, Long> {
    @Query(value = "SELECT nextval('sample_accession_seq')", nativeQuery = true)
    long nextAccessionNumber();

    List<Sample> findAllByBox_IdOrderByIdAsc(Long boxId);
    @Query(value = "SELECT * FROM search_sample(:species, :country)", nativeQuery = true)
    List<SampleSearchProjection> searchSample(
            @Param("species") String speciesName,
            @Param("country") String countryCode
    );
}
