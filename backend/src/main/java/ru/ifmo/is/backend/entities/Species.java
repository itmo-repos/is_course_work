package ru.ifmo.is.backend.entities;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "species")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Species {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "latin_name", length = 160, nullable = false, unique = true)
    private String latinName;

    @Column(name = "local_name", length = 160, nullable = false)
    private String localName;

    @Column(name = "family", length = 120)
    private String family;
}
