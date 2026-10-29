package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import jakarta.validation.constraints.Pattern;
import lombok.*;

@Entity
@Table(name = "country")
@Getter @Setter
@NoArgsConstructor @AllArgsConstructor
public class Country {

    @Id
    @Column(name = "code")
    @Pattern(regexp = "^[A-Z]{2}$")
    private String code;

    @Column(name = "name", length = 120, nullable = false, unique = true)
    private String name;
}
