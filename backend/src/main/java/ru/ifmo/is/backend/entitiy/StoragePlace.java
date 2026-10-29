package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "storage_place")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class StoragePlace {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "chamber_id", nullable = false)
    private Chamber chamber;

    @Column(name = "rack_no", nullable = false)
    private short rackNo;

    @Column(name = "shelf_no", nullable = false)
    private short shelfNo;

    @Column(name = "row_no", nullable = false)
    private short rowNo;

    @Column(name = "is_serviceable", nullable = false)
    private boolean isServiceable = true;
}
