package ru.ifmo.is.backend.entities;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "sample")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Sample {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "box_id", nullable = false)
    private Box box;

    @ManyToOne
    @JoinColumn(name = "species_id", nullable = false)
    private Species species;

    @ManyToOne
    @JoinColumn(name = "origin_country_code", nullable = false)
    private Country originCountry;

    @Column(name = "collection_year", nullable = false)
    private short collectionYear;

    @Column(name = "seed_quantity", nullable = false)
    private int seedQuantity;

    @Column(name = "accession_code", length = 64, nullable = false, unique = true)
    private String accessionCode;

    @Column(name = "note", columnDefinition = "text")
    private String note;
}
