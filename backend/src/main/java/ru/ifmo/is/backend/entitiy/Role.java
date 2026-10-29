package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;

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
