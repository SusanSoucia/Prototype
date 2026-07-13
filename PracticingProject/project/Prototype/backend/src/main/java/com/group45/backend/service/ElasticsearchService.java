package com.group45.backend.service;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.elasticsearch.core.BulkRequest;
import co.elastic.clients.elasticsearch.core.BulkResponse;
import co.elastic.clients.elasticsearch.core.CountResponse;
import co.elastic.clients.elasticsearch.core.DeleteByQueryRequest;
import co.elastic.clients.elasticsearch.core.bulk.BulkOperation;
import co.elastic.clients.elasticsearch.core.bulk.BulkResponseItem;
import com.group45.backend.entity.EsDocument;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

// Elasticsearch操作封装服务
@Service
public class ElasticsearchService {

    private static final Logger logger = LoggerFactory.getLogger(ElasticsearchService.class);

    /**
     * 默认 ES 索引名（向后兼容）。
     */
    public static final String DEFAULT_INDEX_NAME = "knowledge_base";

    @Autowired
    private ElasticsearchClient esClient;

    /**
     * 批量索引文档到默认索引 "knowledge_base"。
     * @deprecated 请使用 {@link #bulkIndex(List, String)} 明确指定索引名
     */
    @Deprecated
    public void bulkIndex(List<EsDocument> documents) {
        bulkIndex(documents, DEFAULT_INDEX_NAME);
    }

    /**
     * 批量索引文档到指定的 Elasticsearch 索引。
     *
     * @param documents 文档列表
     * @param indexName 目标索引名（如 "knowledge_base_研发部库管"）
     */
    public void bulkIndex(List<EsDocument> documents, String indexName) {
        try {
            logger.info("开始批量索引文档到Elasticsearch，索引: {}，文档数量: {}", indexName, documents.size());

            // 将文档列表转换为批量操作列表
            List<BulkOperation> bulkOperations = documents.stream()
                    .map(doc -> BulkOperation.of(op -> op.index(idx -> idx
                            .index(indexName)
                            .id(doc.getId())
                            .document(doc)
                    )))
                    .toList();

            // 创建BulkRequest对象
            BulkRequest request = BulkRequest.of(b -> b.operations(bulkOperations));

            // 执行批量索引操作
            BulkResponse response = esClient.bulk(request);

            // 检查响应结果
            if (response.errors()) {
                logger.error("批量索引过程中发生错误:");
                for (BulkResponseItem item : response.items()) {
                    if (item.error() != null) {
                        logger.error("文档索引失败 - ID: {}, 错误: {}", item.id(), item.error().reason());
                    }
                }
                throw new RuntimeException("批量索引部分失败，请检查日志");
            } else {
                logger.info("批量索引成功完成，索引: {}，文档数量: {}", indexName, documents.size());
            }
        } catch (Exception e) {
            logger.error("批量索引失败，索引: {}，文档数量: {}", indexName, documents.size(), e);
            throw new RuntimeException("批量索引失败", e);
        }
    }

    /**
     * 从默认索引 "knowledge_base" 按 fileMd5 删除文档。
     * @deprecated 请使用 {@link #deleteByFileMd5(String, String)} 明确指定索引名
     */
    @Deprecated
    public void deleteByFileMd5(String fileMd5) {
        deleteByFileMd5(fileMd5, DEFAULT_INDEX_NAME);
    }

    /**
     * 从指定索引按 fileMd5 删除文档。
     */
    public void deleteByFileMd5(String fileMd5, String indexName) {
        try {
            DeleteByQueryRequest request = DeleteByQueryRequest.of(d -> d
                    .index(indexName)
                    .query(q -> q.term(t -> t.field("fileMd5").value(fileMd5)))
            );
            esClient.deleteByQuery(request);
        } catch (Exception e) {
            throw new RuntimeException("删除文档失败", e);
        }
    }

    /**
     * 从默认索引 "knowledge_base" 统计 fileMd5 出现次数。
     * @deprecated 请使用 {@link #countByFileMd5(String, String)} 明确指定索引名
     */
    @Deprecated
    public long countByFileMd5(String fileMd5) {
        return countByFileMd5(fileMd5, DEFAULT_INDEX_NAME);
    }

    /**
     * 从指定索引统计 fileMd5 出现次数。
     */
    public long countByFileMd5(String fileMd5, String indexName) {
        try {
            CountResponse response = esClient.count(c -> c
                    .index(indexName)
                    .query(q -> q.term(t -> t.field("fileMd5").value(fileMd5)))
            );
            return response.count();
        } catch (Exception e) {
            throw new RuntimeException("统计文档失败", e);
        }
    }
}
