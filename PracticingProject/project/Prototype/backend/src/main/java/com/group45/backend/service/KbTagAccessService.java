package com.group45.backend.service;

import com.group45.backend.exception.CustomException;
import com.group45.backend.model.KbTagAccess;
import com.group45.backend.model.OrganizationTag;
import com.group45.backend.repository.KbTagAccessRepository;
import com.group45.backend.repository.OrganizationTagRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/**
 * 知识库-标签访问映射服务。
 * <p>
 * 管理 USER 树标签与知识库（ES 索引）之间的多对多映射关系。
 * 支持子标签继承父标签的访问权限。
 */
@Service
public class KbTagAccessService {

    private static final Logger logger = LoggerFactory.getLogger(KbTagAccessService.class);

    @Autowired
    private KbTagAccessRepository kbTagAccessRepository;

    @Autowired
    private OrganizationTagRepository organizationTagRepository;

    /**
     * 授予 USER 树的标签对某知识库的访问权限。
     *
     * @param kbName    ES 索引名（如 "knowledge_base_研发部库管"）
     * @param tagId     USER 树下的标签 ID
     * @param createdBy 操作者用户名
     */
    @Transactional
    public KbTagAccess grantAccess(String kbName, String tagId, String createdBy) {
        if (kbTagAccessRepository.existsByKbNameAndTagId(kbName, tagId)) {
            throw new CustomException("该标签已被授权访问此知识库", HttpStatus.CONFLICT);
        }

        // 验证标签存在
        OrganizationTag tag = organizationTagRepository.findByTagId(tagId)
                .orElseThrow(() -> new CustomException("组织标签不存在: " + tagId, HttpStatus.NOT_FOUND));

        KbTagAccess access = new KbTagAccess();
        access.setKbName(kbName);
        access.setTagId(tagId);
        access.setCreatedBy(createdBy);

        KbTagAccess saved = kbTagAccessRepository.save(access);
        logger.info("知识库授权成功: kb={}, tag={}, by={}", kbName, tagId, createdBy);
        return saved;
    }

    /**
     * 撤销 USER 树标签对某知识库的访问权限。
     */
    @Transactional
    public void revokeAccess(String kbName, String tagId) {
        if (!kbTagAccessRepository.existsByKbNameAndTagId(kbName, tagId)) {
            throw new CustomException("该标签未被授权访问此知识库", HttpStatus.NOT_FOUND);
        }
        kbTagAccessRepository.deleteByKbNameAndTagId(kbName, tagId);
        logger.info("知识库授权撤销: kb={}, tag={}", kbName, tagId);
    }

    /**
     * 计算用户可访问的所有知识库（ES 索引）名称。
     * <p>
     * 遍历用户的每个标签，向上追溯到根（parentTag=null），收集路径上所有标签的授权知识库。
     * 子标签自动继承父标签的授权。
     *
     * @param userTags 用户持有的标签 ID 集合
     * @return 该用户可检索的 ES 索引名列表（去重）
     */
    public List<String> getAccessibleKbs(Set<String> userTags) {
        if (userTags == null || userTags.isEmpty()) {
            return List.of();
        }

        Set<String> allTags = new HashSet<>();

        // 对每个用户标签，向上追溯所有祖先标签
        for (String tagId : userTags) {
            allTags.add(tagId);
            String currentTagId = tagId;
            while (currentTagId != null) {
                Optional<OrganizationTag> tagOpt = organizationTagRepository.findByTagId(currentTagId);
                if (tagOpt.isEmpty()) break;
                String parentTag = tagOpt.get().getParentTag();
                if (parentTag != null && !parentTag.isEmpty()) {
                    allTags.add(parentTag);
                    currentTagId = parentTag;
                } else {
                    break;
                }
            }
        }

        // 查询所有这些标签被授权了哪些知识库
        List<KbTagAccess> accesses = kbTagAccessRepository.findByTagIdIn(new ArrayList<>(allTags));
        return accesses.stream()
                .map(KbTagAccess::getKbName)
                .distinct()
                .toList();
    }

    /**
     * 查询某知识库被授权给了哪些 USER 树标签。
     */
    public List<KbTagAccess> getAuthorizedTags(String kbName) {
        return kbTagAccessRepository.findByKbName(kbName);
    }

    /**
     * 获取所有知识库-标签映射。
     */
    public List<KbTagAccess> getAllMappings() {
        return kbTagAccessRepository.findAll();
    }
}
