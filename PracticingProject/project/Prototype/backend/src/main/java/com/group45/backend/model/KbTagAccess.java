package com.group45.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;

/**
 * 知识库-标签访问映射实体。
 * <p>
 * 记录 USER 树下的标签被授权访问哪些知识库（ES 索引）。
 * 权限继承规则：标签 A 映射到库 K → 标签 A 及其所有子标签均可检索库 K。
 */
@Data
@Entity
@Table(name = "kb_tag_access", uniqueConstraints = {
        @UniqueConstraint(name = "uk_kb_tag", columnNames = {"kb_name", "tag_id"})
}, indexes = {
        @Index(name = "idx_tag_id", columnList = "tag_id")
})
public class KbTagAccess {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * ES 索引名（如 "knowledge_base_研发部库管"）。
     */
    @Column(name = "kb_name", length = 100, nullable = false)
    private String kbName;

    /**
     * USER 树下的标签 ID。
     */
    @Column(name = "tag_id", length = 255, nullable = false)
    private String tagId;

    /**
     * 授权创建者用户名。
     */
    @Column(name = "created_by", length = 64)
    private String createdBy;

    @CreationTimestamp
    @Column(name = "created_at")
    private LocalDateTime createdAt;
}
