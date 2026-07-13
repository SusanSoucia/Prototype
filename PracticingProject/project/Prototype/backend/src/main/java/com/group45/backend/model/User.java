package com.group45.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.LocalDateTime;

@Data
@Entity
@Table(name = "users", uniqueConstraints = @UniqueConstraint(columnNames = "username"))
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String username;

    @Column(nullable = false)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    @Column(name = "org_tags")
    private String orgTags; // 用户所属组织标签，多个用逗号分隔

    @Column(name = "primary_org")
    private String primaryOrg; // 用户主组织标签

    @CreationTimestamp
    private LocalDateTime createdAt;

    @UpdateTimestamp
    private LocalDateTime updatedAt;

    public enum Role {
        USER,           // 普通用户（USER 树下）
        LIBRARY_ADMIN,  // 库管（ADMIN 子标签持有者，可管理特定知识库文档）
        ADMIN           // 超级管理员（ADMIN 标签持有者）
    }
}
