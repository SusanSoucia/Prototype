package com.group45.backend.service;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.elasticsearch._types.query_dsl.Query;
import co.elastic.clients.elasticsearch.core.SearchResponse;
import com.group45.backend.client.EmbeddingClient;
import com.group45.backend.entity.EsDocument;
import com.group45.backend.entity.SearchResult;
import com.group45.backend.model.User;
import com.group45.backend.exception.CustomException;
import com.group45.backend.repository.UserRepository;
import com.group45.backend.repository.FileUploadRepository;
import com.group45.backend.model.FileUpload;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import co.elastic.clients.elasticsearch._types.query_dsl.Operator;

import java.util.Collections;
import java.util.List;
import java.util.ArrayList;
import java.util.Set;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 混合搜索服务，结合文本匹配和向量相似度搜索
 * 支持权限过滤，确保用户只能搜索其有权限访问的文档
 */
@Service
public class HybridSearchService {

    private static final Logger logger = LoggerFactory.getLogger(HybridSearchService.class);

    @Autowired
    private ElasticsearchClient esClient;

    @Autowired
    private EmbeddingClient embeddingClient;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private OrgTagCacheService orgTagCacheService;

    @Autowired
    private FileUploadRepository fileUploadRepository;

    /**
     * 使用文本匹配和向量相似度进行混合搜索，支持权限过滤
     * 该方法确保用户只能搜索其有权限访问的文档（自己的文档、公开文档、所属组织的文档）
     *
     * @param query  查询字符串
     * @param userId 用户ID
     * @param topK   返回结果数量
     * @return 搜索结果列表
     */
    public List<SearchResult> searchWithPermission(String query, String userId, int topK) {
        logger.debug("开始带权限搜索，查询: {}, 用户ID: {}", query, userId);
        
        try {
            AccessContext accessContext = resolveAccessContext(userId);
            logger.debug("用户 {} 的文档访问上下文: {}", userId, accessContext);

            // 生成查询向量
            final List<Float> queryVector = embedToVectorList(query, userId);
            final Query permissionFilter = buildPermissionFilter(accessContext);

            // 如果向量生成失败，仅使用文本匹配
            if (queryVector == null) {
                logger.warn("向量生成失败，仅使用文本匹配进行搜索");
                return textOnlySearchWithPermission(query, accessContext, topK);
            }

            logger.debug("向量生成成功，开始执行混合搜索 KNN");

            SearchResponse<EsDocument> response = esClient.search(s -> {
                        s.index("knowledge_base");
                        // KNN 召回
                        int recallK = topK * 30; // KNN 召回窗口
                        s.knn(kn -> kn
                                .field("vector")
                                .queryVector(queryVector)
                                .k(recallK)
                                .numCandidates(recallK)
                                .filter(permissionFilter)
                        );
                        // 必须命中关键词 + 权限过滤
                        s.query(q -> q.bool(b -> b
                                .must(mst -> mst.match(m -> m.field("textContent").query(query)))
                                .filter(permissionFilter)
                        ));

                        // 第二阶段 BM25 rescore
                        s.rescore(r -> r
                                .windowSize(recallK)
                                .query(rq -> rq
                                        .queryWeight(0.2d)               // 保留部分 KNN 分
                                        .rescoreQueryWeight(1.0d)        // BM25 主导
                                        .query(rqq -> rqq.match(m -> m
                                                .field("textContent")
                                                .query(query)
                                                .operator(Operator.And)
                                        ))
                                )
                        );
                        s.size(topK);
                        return s;
                    }, EsDocument.class);

            logger.debug("Elasticsearch查询执行完成，命中数量: {}, 最大分数: {}", 
                response.hits().total().value(), response.hits().maxScore());

            List<SearchResult> results = response.hits().hits().stream()
                    .filter(hit -> hit.source() != null && canAccess(hit.source(), accessContext))
                    .map(hit -> {
                        assert hit.source() != null;
                        logger.debug("搜索结果 - 文件: {}, 块: {}, 分数: {}, 内容: {}", 
                            hit.source().getFileMd5(), hit.source().getChunkId(), hit.score(), 
                            hit.source().getTextContent().substring(0, Math.min(50, hit.source().getTextContent().length())));
                        return new SearchResult(
                                hit.source().getFileMd5(),
                                hit.source().getChunkId(),
                                hit.source().getTextContent(),
                                hit.score(),
                                hit.source().getUserId(),
                                hit.source().getOrgTag(),
                                hit.source().isPublic(),
                                null,
                                hit.source().getPageNumber(),
                                hit.source().getAnchorText(),
                                "HYBRID",
                                hit.source().getTextContent()
                        );
                    })
                    .toList();

            logger.debug("返回搜索结果数量: {}", results.size());
            attachFileNames(results);
            return results;
        } catch (Exception e) {
            logger.error("带权限的搜索失败", e);
            // 发生异常时尝试使用纯文本搜索作为后备方案
            try {
                logger.info("尝试使用纯文本搜索作为后备方案");
                return textOnlySearchWithPermission(query, resolveAccessContext(userId), topK);
            } catch (Exception fallbackError) {
                logger.error("后备搜索也失败", fallbackError);
                return Collections.emptyList();
            }
        }
    }

    /**
     * 仅使用文本匹配的带权限搜索方法
     */
    private List<SearchResult> textOnlySearchWithPermission(String query, AccessContext accessContext, int topK) {
        try {
            logger.debug("开始执行纯文本搜索，访问上下文: {}", accessContext);
            final Query permissionFilter = buildPermissionFilter(accessContext);

            SearchResponse<EsDocument> response = esClient.search(s -> s
                    .index("knowledge_base")
                    .query(q -> q
                            .bool(b -> b
                                    // 匹配内容相关性
                                    .must(m -> m
                                            .match(ma -> ma
                                                    .field("textContent")
                                                    .query(query)
                                            )
                                    )
                                    // 权限过滤
                                    .filter(permissionFilter)
                            )
                    )
                    .minScore(0.3d)
                    .size(topK),
                    EsDocument.class
            );

            logger.debug("纯文本查询执行完成，命中数量: {}, 最大分数: {}", 
                response.hits().total().value(), response.hits().maxScore());

            List<SearchResult> results = response.hits().hits().stream()
                    .filter(hit -> hit.source() != null && canAccess(hit.source(), accessContext))
                    .map(hit -> {
                        assert hit.source() != null;
                        logger.debug("纯文本搜索结果 - 文件: {}, 块: {}, 分数: {}, 内容: {}", 
                            hit.source().getFileMd5(), hit.source().getChunkId(), hit.score(), 
                            hit.source().getTextContent().substring(0, Math.min(50, hit.source().getTextContent().length())));
                        return new SearchResult(
                                hit.source().getFileMd5(),
                                hit.source().getChunkId(),
                                hit.source().getTextContent(),
                                hit.score(),
                                hit.source().getUserId(),
                                hit.source().getOrgTag(),
                                hit.source().isPublic(),
                                null,
                                hit.source().getPageNumber(),
                                hit.source().getAnchorText(),
                                "TEXT_ONLY",
                                hit.source().getTextContent()
                        );
                    })
                    .toList();

            logger.debug("返回纯文本搜索结果数量: {}", results.size());
            attachFileNames(results);
            return results;
        } catch (Exception e) {
            logger.error("纯文本搜索失败", e);
            return new ArrayList<>();
        }
    }

    /**
     * 原始搜索方法，不包含权限过滤，保留向后兼容性
     */
    public List<SearchResult> search(String query, int topK) {
        try {
            logger.debug("开始混合检索，查询: {}, topK: {}", query, topK);
            logger.warn("使用了没有权限过滤的搜索方法，建议使用 searchWithPermission 方法");

            // 生成查询向量
            final List<Float> queryVector = embedToVectorList(query, "system");
            
            // 如果向量生成失败，仅使用文本匹配
            if (queryVector == null) {
                logger.warn("向量生成失败，仅使用文本匹配进行搜索");
                return textOnlySearch(query, topK);
            }

            SearchResponse<EsDocument> response = esClient.search(s -> {
                        s.index("knowledge_base");
                        int recallK = topK * 30;
                        s.knn(kn -> kn
                                .field("vector")
                                .queryVector(queryVector)
                                .k(recallK)
                                .numCandidates(recallK)
                        );

                        // 过滤仅保留包含关键词的文本
                        s.query(q -> q.match(m -> m.field("textContent").query(query)));

                        // rescore BM25
                        s.rescore(r -> r
                                .windowSize(recallK)
                                .query(rq -> rq
                                        .queryWeight(0.2d)
                                        .rescoreQueryWeight(1.0d)
                                        .query(rqq -> rqq.match(m -> m
                                                .field("textContent")
                                                .query(query)
                                                .operator(Operator.And)
                                        ))
                                )
                        );
                        s.size(topK);
                        return s;
                    }, EsDocument.class);

            return response.hits().hits().stream()
                    .map(hit -> {
                        assert hit.source() != null;
                        return new SearchResult(
                                hit.source().getFileMd5(),
                                hit.source().getChunkId(),
                                hit.source().getTextContent(),
                                hit.score(),
                                null,
                                null,
                                false,
                                null,
                                hit.source().getPageNumber(),
                                hit.source().getAnchorText(),
                                "HYBRID",
                                hit.source().getTextContent()
                        );
                    })
                    .toList();
        } catch (Exception e) {
            logger.error("搜索失败", e);
            // 发生异常时尝试使用纯文本搜索作为后备方案
            try {
                logger.info("尝试使用纯文本搜索作为后备方案");
                return textOnlySearch(query, topK);
            } catch (Exception fallbackError) {
                logger.error("后备搜索也失败", fallbackError);
                throw new RuntimeException("搜索完全失败", fallbackError);
            }
        }
    }

    /**
     * 仅使用文本匹配的搜索方法
     */
    private List<SearchResult> textOnlySearch(String query, int topK) throws Exception {
        SearchResponse<EsDocument> response = esClient.search(s -> s
                .index("knowledge_base")
                .query(q -> q
                        .match(m -> m
                                .field("textContent")
                                .query(query)
                        )
                )
                .size(topK),
                EsDocument.class
        );

        return response.hits().hits().stream()
                .map(hit -> {
                    assert hit.source() != null;
                    return new SearchResult(
                            hit.source().getFileMd5(),
                            hit.source().getChunkId(),
                            hit.source().getTextContent(),
                            hit.score(),
                            null,
                            null,
                            false,
                            null,
                            hit.source().getPageNumber(),
                            hit.source().getAnchorText(),
                            "TEXT_ONLY",
                            hit.source().getTextContent()
                    );
                })
                .toList();
    }

    /**
     * 生成查询向量，返回 List<Float>，失败时返回 null
     */
    private List<Float> embedToVectorList(String text, String requesterId) {
        try {
            List<float[]> vecs = embeddingClient.embed(List.of(text), requesterId, EmbeddingClient.UsageType.QUERY);
            if (vecs == null || vecs.isEmpty()) {
                logger.warn("生成的向量为空");
                return null;
            }
            float[] raw = vecs.get(0);
            List<Float> list = new ArrayList<>(raw.length);
            for (float v : raw) {
                list.add(v);
            }
            return list;
        } catch (Exception e) {
            logger.error("生成向量失败", e);
            return null;
        }
    }

    private Query buildPermissionFilter(AccessContext accessContext) {
        if (accessContext != null && accessContext.admin()) {
            return Query.of(q -> q.matchAll(m -> m));
        }

        return Query.of(q -> q.bool(b -> {
            if (accessContext != null && accessContext.userDbId() != null) {
                b.should(s -> s.term(t -> t.field("userId").value(accessContext.userDbId())));
            }
            b.should(s -> s.term(t -> t.field("isPublic").value(true)));

            if (accessContext != null && accessContext.documentAccessTags() != null) {
                accessContext.documentAccessTags().stream()
                        .filter(tag -> tag != null && !tag.isBlank())
                        .distinct()
                        .forEach(tag -> b.should(s -> s.term(t -> t.field("orgTag").value(tag))));
            }

            return b.minimumShouldMatch("1");
        }));
    }

    private boolean canAccess(EsDocument document, AccessContext accessContext) {
        if (document == null) {
            return false;
        }
        if (accessContext != null && accessContext.admin()) {
            return true;
        }
        if (accessContext != null && accessContext.userDbId() != null && accessContext.userDbId().equals(document.getUserId())) {
            return true;
        }
        if (document.isPublic()) {
            return true;
        }
        return accessContext != null
                && accessContext.documentAccessTags() != null
                && accessContext.documentAccessTags().contains(document.getOrgTag());
    }
    
    /**
     * 获取用户文档访问上下文（直接标签及其所有子标签）
     */
    private AccessContext resolveAccessContext(String userId) {
        logger.debug("获取用户文档访问上下文，用户ID: {}", userId);
        try {
            User user = resolveUser(userId);
            String userDbId = String.valueOf(user.getId());
            if (User.Role.ADMIN.equals(user.getRole())) {
                return new AccessContext(userDbId, true, List.of());
            }
            
            List<String> documentAccessTags = orgTagCacheService.getDocumentAccessOrgTags(parseOrgTags(user.getOrgTags()));
            logger.debug("用户 {} 的文档访问组织标签: {}", user.getUsername(), documentAccessTags);
            return new AccessContext(userDbId, false, documentAccessTags);
        } catch (Exception e) {
            logger.error("获取用户文档访问上下文失败: {}", e.getMessage(), e);
            throw new RuntimeException("获取用户文档访问上下文失败", e);
        }
    }

    private User resolveUser(String userId) {
        try {
            Long userIdLong = Long.parseLong(userId);
            logger.debug("解析用户ID为Long: {}", userIdLong);
            return userRepository.findById(userIdLong)
                    .orElseThrow(() -> new CustomException("User not found with ID: " + userId, HttpStatus.NOT_FOUND));
        } catch (NumberFormatException e) {
            logger.debug("用户ID不是数字格式，作为用户名查找: {}", userId);
            return userRepository.findByUsername(userId)
                    .orElseThrow(() -> new CustomException("User not found: " + userId, HttpStatus.NOT_FOUND));
        }
    }

    private List<String> parseOrgTags(String orgTags) {
        if (orgTags == null || orgTags.isBlank()) {
            return List.of();
        }
        return java.util.Arrays.stream(orgTags.split(","))
                .map(String::trim)
                .filter(tag -> !tag.isEmpty())
                .toList();
    }

    private void attachFileNames(List<SearchResult> results) {
        if (results == null || results.isEmpty()) {
            return;
        }
        try {
            // 收集所有唯一的 fileMd5
            Set<String> md5Set = results.stream()
                    .map(SearchResult::getFileMd5)
                    .collect(Collectors.toSet());
            List<FileUpload> uploads = fileUploadRepository.findByFileMd5In(new java.util.ArrayList<>(md5Set));
            Map<String, String> md5ToName = uploads.stream()
                    .collect(Collectors.toMap(FileUpload::getFileMd5, FileUpload::getFileName, (existing, replacement) -> existing));
            // 填充文件名
            results.forEach(r -> r.setFileName(md5ToName.get(r.getFileMd5())));
        } catch (Exception e) {
            logger.error("补充文件名失败", e);
        }
    }

    private record AccessContext(String userDbId, boolean admin, List<String> documentAccessTags) {
    }
}
