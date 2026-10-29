package ru.ifmo.is.backend.entitiy;

import jakarta.persistence.*;
import lombok.*;
import ru.ifmo.is.backend.entitiy.enums.RoleCode;

import java.io.Serializable;
import java.time.OffsetDateTime;

@Entity
@Table(name = "employee_role")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class EmployeeRole {

    @EmbeddedId
    private EmployeeRoleId employeeRoleId = new EmployeeRoleId();

    @ManyToOne
    @MapsId("employeeId")
    @JoinColumn(name = "employee_id")
    private Employee employee;

    @ManyToOne
    @MapsId("roleCode")
    @JoinColumn(name = "role_code")
    private Role role;

    @Column(name = "assigned_at", nullable = false)
    private OffsetDateTime assignedAt = OffsetDateTime.now();

    @ManyToOne
    @JoinColumn(name = "assigned_by")
    private Employee assignedBy;

    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EmployeeRoleId implements Serializable {
        private Long employeeId;

        @Enumerated(EnumType.STRING)
        private RoleCode roleCode;
    }

}
