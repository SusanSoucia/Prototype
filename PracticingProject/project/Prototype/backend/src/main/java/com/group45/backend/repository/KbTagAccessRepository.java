package com.group45.backend.repository;

import com.group45.backend.model.KbTagAccess;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 知识库-标签访问映射 Repository。
 */
@Repository
public interface KbTagAccessRepository extends JpaRepository<KbTagAccess, Long> {

    /**
     * 查询某知识库被授权给哪些标签。
     */
    List<KbTagAccess> findByKbName(String kbName);

    /**
     * 查询某标签可以访问哪些知识库。
     */
    List<KbTagAccess> findByTagId(String tagId);

    /**
     * 查询某标签可以访问的知识库名列表。
     */
    List<KbTagAccess> findByTagIdIn(List<String> tagIds);

    /**
     * 检查某知识库-标签映射是否存在。
     */
    boolean existsByKbNameAndTagId(String kbName, String tagId);

    /**
     * 删除某知识库-标签映射。
     */
    void deleteByKbNameAndTagId(String kbName, String tagId);

    /**
     * 删除某知识库的所有映射。
     */
    void deleteByKbName(String kbName);

    /**
     * 查找特定映射。
     */
    Optional<KbTagAccess> findByKbNameAndTagId(String kbName, String tagId);
}
