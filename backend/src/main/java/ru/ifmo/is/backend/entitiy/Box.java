package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.ColumnTransformer;
import ru.ifmo.is.backend.entitiy.enums.BoxStatus;
import java.time.OffsetDateTime;

@Entity
@Table(name = "box")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Box {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "batch_id", nullable = false)
    private Batch batch;

    @Column(name = "seq_no", nullable = false)
    private short seqNo;

    @Column(name = "barcode", length = 64, unique = true)
    private String barcode;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    @ColumnTransformer(write = "?::box_status")
    private BoxStatus status = BoxStatus.FORMED;

    @OneToOne
    @JoinColumn(name = "storage_place_id")
    private StoragePlace storagePlace;

    @Column(name = "write_off_reason")
    private String writeOffReason;

    @Column(name = "placed_at")
    private OffsetDateTime placedAt;

    @Column(name = "written_off_at")
    private OffsetDateTime writtenOffAt;

    @Column(name = "withdrawn_at")
    private OffsetDateTime withdrawnAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();
}
