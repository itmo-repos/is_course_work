package ru.ifmo.is.backend.entities;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entities.enums.RoleCode;

@Entity
@Table(name = "role")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Role {

    @Id
    @Enumerated(EnumType.STRING)
    @Column(name = "code", length = 32)
    private RoleCode code;

    @Column(name = "name", length = 120, nullable = false)
    private String name;

    @Column(name = "description", columnDefinition = "text")
    private String description;
}
