-- Group45 企业知识问答系统 MySQL 初始化脚本
-- 适用数据库：MySQL 8.x
-- 说明：
-- 1. 本脚本根据当前后端 JPA 实体编写，用于部署初始化、验收和手动建库。
-- 2. 脚本不删除已有表和数据；重复执行时不会清空业务数据。
-- 3. 后端仍可通过 spring.jpa.hibernate.ddl-auto=update 自动补齐表结构。

CREATE DATABASE IF NOT EXISTS group45_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE group45_db;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  username VARCHAR(255) NOT NULL COMMENT '用户名',
  password VARCHAR(255) NOT NULL COMMENT 'BCrypt加密后的密码',
  role VARCHAR(255) NOT NULL COMMENT '角色：USER / ADMIN',
  org_tags VARCHAR(255) DEFAULT NULL COMMENT '用户所属组织标签，多个标签用逗号分隔',
  primary_org VARCHAR(255) DEFAULT NULL COMMENT '用户主组织标签',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

CREATE TABLE IF NOT EXISTS organization_tags (
  tag_id VARCHAR(255) NOT NULL COMMENT '组织标签ID',
  name VARCHAR(255) NOT NULL COMMENT '组织标签名称',
  description TEXT DEFAULT NULL COMMENT '组织标签描述',
  parent_tag VARCHAR(255) DEFAULT NULL COMMENT '父组织标签ID',
  upload_max_size_bytes BIGINT DEFAULT NULL COMMENT '非管理员上传文件大小上限，NULL表示不限制',
  created_by BIGINT NOT NULL COMMENT '创建者用户ID',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
  PRIMARY KEY (tag_id),
  KEY idx_org_tags_created_by (created_by),
  CONSTRAINT fk_org_tags_created_by FOREIGN KEY (created_by) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='组织标签表';

CREATE TABLE IF NOT EXISTS file_upload (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '文件上传记录ID',
  file_md5 VARCHAR(32) NOT NULL COMMENT '文件MD5',
  file_name VARCHAR(255) DEFAULT NULL COMMENT '原始文件名',
  total_size BIGINT NOT NULL DEFAULT 0 COMMENT '文件总大小，单位字节',
  status INT NOT NULL DEFAULT 0 COMMENT '上传状态：0上传中，1已完成，2合并中',
  user_id VARCHAR(64) NOT NULL COMMENT '上传用户ID',
  org_tag VARCHAR(255) DEFAULT NULL COMMENT '文件所属组织标签',
  is_public BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否公开',
  estimated_embedding_tokens BIGINT DEFAULT NULL COMMENT '预估Embedding Token数',
  estimated_chunk_count INT DEFAULT NULL COMMENT '预估文本块数量',
  actual_embedding_tokens BIGINT DEFAULT NULL COMMENT '实际Embedding Token数',
  actual_chunk_count INT DEFAULT NULL COMMENT '实际文本块数量',
  vectorization_status VARCHAR(32) DEFAULT NULL COMMENT '向量化状态',
  vectorization_error_message VARCHAR(1000) DEFAULT NULL COMMENT '向量化错误信息',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  merged_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '合并完成时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_file_upload_md5_user (file_md5, user_id),
  KEY idx_file_upload_user_id (user_id),
  KEY idx_file_upload_org_tag (org_tag),
  KEY idx_file_upload_status (status),
  KEY idx_file_upload_vectorization_status (vectorization_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文件上传记录表';

CREATE TABLE IF NOT EXISTS chunk_info (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '分块ID',
  file_md5 VARCHAR(32) NOT NULL COMMENT '文件MD5',
  chunk_index INT NOT NULL COMMENT '文件分片序号',
  chunk_md5 VARCHAR(32) NOT NULL COMMENT '分片MD5',
  storage_path VARCHAR(255) NOT NULL COMMENT '分片存储路径',
  PRIMARY KEY (id),
  UNIQUE KEY uk_file_md5_chunk_index (file_md5, chunk_index),
  KEY idx_chunk_info_file_md5 (file_md5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='上传分片信息表';

CREATE TABLE IF NOT EXISTS document_vectors (
  vector_id BIGINT NOT NULL AUTO_INCREMENT COMMENT '文档向量记录ID',
  file_md5 VARCHAR(32) NOT NULL COMMENT '文件MD5',
  chunk_id INT NOT NULL COMMENT '文本块序号',
  text_content LONGTEXT DEFAULT NULL COMMENT '文本块内容',
  page_number INT DEFAULT NULL COMMENT 'PDF页码',
  anchor_text VARCHAR(512) DEFAULT NULL COMMENT '引用锚点文本',
  model_version VARCHAR(32) DEFAULT NULL COMMENT 'Embedding模型版本',
  user_id VARCHAR(64) NOT NULL COMMENT '上传用户ID',
  org_tag VARCHAR(50) DEFAULT NULL COMMENT '文件所属组织标签',
  is_public BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否公开',
  PRIMARY KEY (vector_id),
  KEY idx_document_vectors_file_md5 (file_md5),
  KEY idx_document_vectors_user_id (user_id),
  KEY idx_document_vectors_org_tag (org_tag),
  KEY idx_document_vectors_page_number (page_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='文档文本块和向量元数据表';

CREATE TABLE IF NOT EXISTS conversation_sessions (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '会话ID',
  user_id BIGINT NOT NULL COMMENT '用户ID',
  conversation_id VARCHAR(64) NOT NULL COMMENT '逻辑会话ID',
  title VARCHAR(255) DEFAULT NULL COMMENT '会话标题',
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态：ACTIVE / ARCHIVED',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY idx_cs_conversation_id (conversation_id),
  KEY idx_cs_user_id (user_id),
  KEY idx_cs_status (status),
  CONSTRAINT fk_conversation_sessions_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对话会话表';

CREATE TABLE IF NOT EXISTS conversations (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '对话记录ID',
  user_id BIGINT NOT NULL COMMENT '用户ID',
  question TEXT NOT NULL COMMENT '用户问题',
  answer TEXT NOT NULL COMMENT '系统回答',
  conversation_id VARCHAR(64) DEFAULT NULL COMMENT '逻辑会话ID',
  reference_mappings_json LONGTEXT DEFAULT NULL COMMENT '引用映射JSON',
  timestamp DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '对话时间',
  PRIMARY KEY (id),
  KEY idx_user_id (user_id),
  KEY idx_timestamp (timestamp),
  KEY idx_conversation_id (conversation_id),
  CONSTRAINT fk_conversations_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='对话记录表';

CREATE TABLE IF NOT EXISTS user_daily_chat_count (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '记录ID',
  user_id VARCHAR(50) NOT NULL COMMENT '用户ID',
  record_date DATE NOT NULL COMMENT '记录日期',
  chat_request_count BIGINT NOT NULL DEFAULT 0 COMMENT '聊天请求次数',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY uk_user_date (user_id, record_date),
  KEY idx_record_date (record_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户每日聊天次数表';

CREATE TABLE IF NOT EXISTS user_token_record (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT 'Token变动记录ID',
  user_id VARCHAR(255) NOT NULL COMMENT '用户ID',
  record_date DATE NOT NULL COMMENT '记录日期',
  token_type VARCHAR(20) NOT NULL COMMENT 'Token类型：LLM / EMBEDDING',
  change_type VARCHAR(20) NOT NULL COMMENT '变动类型：INCREASE / CONSUME',
  amount BIGINT NOT NULL COMMENT '变动数量',
  balance_before BIGINT DEFAULT NULL COMMENT '变动前余额',
  balance_after BIGINT DEFAULT NULL COMMENT '变动后余额',
  reason VARCHAR(500) DEFAULT NULL COMMENT '变动原因',
  remark VARCHAR(500) DEFAULT NULL COMMENT '备注',
  request_count BIGINT NOT NULL DEFAULT 0 COMMENT '请求次数',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  PRIMARY KEY (id),
  KEY idx_user_date (user_id, record_date),
  KEY idx_user_token_record_token_type (token_type),
  KEY idx_user_token_record_change_type (change_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户Token变动记录表';

CREATE TABLE IF NOT EXISTS rate_limit_configs (
  config_key VARCHAR(64) NOT NULL COMMENT '限流配置项',
  single_max INT DEFAULT NULL COMMENT '单窗口最大次数',
  single_window_seconds BIGINT DEFAULT NULL COMMENT '单窗口秒数',
  minute_max BIGINT DEFAULT NULL COMMENT '分钟窗口限额',
  minute_window_seconds BIGINT DEFAULT NULL COMMENT '分钟窗口秒数',
  day_max BIGINT DEFAULT NULL COMMENT '日窗口限额',
  day_window_seconds BIGINT DEFAULT NULL COMMENT '日窗口秒数',
  updated_by VARCHAR(255) NOT NULL COMMENT '更新人',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
  PRIMARY KEY (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='限流配置表';

CREATE TABLE IF NOT EXISTS model_provider_configs (
  id BIGINT NOT NULL AUTO_INCREMENT COMMENT '模型配置ID',
  config_scope VARCHAR(32) NOT NULL COMMENT '配置范围：llm / embedding',
  provider_code VARCHAR(64) NOT NULL COMMENT '模型供应商编码',
  display_name VARCHAR(128) NOT NULL COMMENT '显示名称',
  api_style VARCHAR(64) NOT NULL COMMENT 'API风格',
  api_base_url VARCHAR(512) NOT NULL COMMENT 'API基础地址',
  model_name VARCHAR(255) NOT NULL COMMENT '模型名称',
  api_key_ciphertext VARCHAR(2048) DEFAULT NULL COMMENT '加密后的API Key',
  embedding_dimension INT DEFAULT NULL COMMENT 'Embedding维度',
  enabled BIT(1) NOT NULL DEFAULT b'1' COMMENT '是否启用',
  active BIT(1) NOT NULL DEFAULT b'0' COMMENT '是否为当前激活配置',
  updated_by VARCHAR(255) NOT NULL COMMENT '更新人',
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) COMMENT '创建时间',
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新时间',
  PRIMARY KEY (id),
  UNIQUE KEY idx_model_provider_scope_provider (config_scope, provider_code),
  KEY idx_model_provider_scope (config_scope)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='模型供应商配置表';

SET FOREIGN_KEY_CHECKS = 1;

-- 默认限流配置。应用没有这些行时会使用代码中的默认值；写入数据库后可在管理端调整。
INSERT INTO rate_limit_configs (
  config_key,
  single_max,
  single_window_seconds,
  minute_max,
  minute_window_seconds,
  day_max,
  day_window_seconds,
  updated_by
) VALUES
  ('chat-message', 30, 60, NULL, NULL, NULL, NULL, 'system'),
  ('llm-global-token', NULL, NULL, 120000, 60, 8000000, 86400, 'system'),
  ('embedding-upload-token', NULL, NULL, 200000, 60, 20000000, 86400, 'system'),
  ('embedding-query-request', NULL, NULL, 60, 60, 5000, 86400, 'system'),
  ('embedding-query-global-token', NULL, NULL, 60000, 60, 4000000, 86400, 'system')
ON DUPLICATE KEY UPDATE
  single_max = VALUES(single_max),
  single_window_seconds = VALUES(single_window_seconds),
  minute_max = VALUES(minute_max),
  minute_window_seconds = VALUES(minute_window_seconds),
  day_max = VALUES(day_max),
  day_window_seconds = VALUES(day_window_seconds),
  updated_by = VALUES(updated_by),
  updated_at = CURRENT_TIMESTAMP(6);

-- 默认模型供应商配置。
-- api_key_ciphertext 留空，真实 Key 推荐通过环境变量或管理端写入，避免明文进入 SQL 文件。
INSERT INTO model_provider_configs (
  config_scope,
  provider_code,
  display_name,
  api_style,
  api_base_url,
  model_name,
  api_key_ciphertext,
  embedding_dimension,
  enabled,
  active,
  updated_by
) VALUES
  ('llm', 'deepseek', 'DeepSeek', 'openai-compatible', 'https://api.deepseek.com/v1', 'deepseek-chat', NULL, NULL, b'1', b'1', 'system'),
  ('llm', 'qwen', 'Qwen', 'openai-compatible', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'qwen-flash', NULL, NULL, b'1', b'0', 'system'),
  ('llm', 'zhipu', 'ZhipuAI', 'openai-compatible', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4.5-air', NULL, NULL, b'1', b'0', 'system'),
  ('embedding', 'aliyun', '阿里云', 'openai-compatible', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'text-embedding-v4', NULL, 2048, b'1', b'1', 'system'),
  ('embedding', 'zhipu', '智谱AI', 'openai-compatible', 'https://open.bigmodel.cn/api/paas/v4', 'embedding-3', NULL, 2048, b'1', b'0', 'system')
ON DUPLICATE KEY UPDATE
  display_name = VALUES(display_name),
  api_style = VALUES(api_style),
  api_base_url = VALUES(api_base_url),
  model_name = VALUES(model_name),
  embedding_dimension = VALUES(embedding_dimension),
  enabled = VALUES(enabled),
  active = VALUES(active),
  updated_by = VALUES(updated_by),
  updated_at = CURRENT_TIMESTAMP(6);

-- 管理员账号和默认组织标签由后端启动时根据 .env 自动创建：
-- ADMIN_BOOTSTRAP_ENABLED=true
-- ADMIN_BOOTSTRAP_USERNAME=admin
-- ADMIN_BOOTSTRAP_PASSWORD=请使用强密码
-- ADMIN_BOOTSTRAP_ORG_TAGS=default,admin
--
-- 不建议在 SQL 中写入管理员密码哈希，避免脚本中沉淀固定口令。
