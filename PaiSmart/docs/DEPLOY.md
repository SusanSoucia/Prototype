# PaiSmart 部署文档

> 部署日期：2026-06-24  
> 环境：WSL2 (Ubuntu) / Linux 6.6.87.2-microsoft-standard-WSL2

---

## 前置环境

| 依赖 | 版本 | 来源 |
|------|------|------|
| Java | OpenJDK 21.0.11 | 系统预装 |
| Maven | 3.9.9 | 手动安装到 `~/.local/maven` |
| Node.js | v22.16.0 | `~/.local/node-v22.16.0-linux-x64` |
| pnpm | 11.9.0 | `npm install -g pnpm` |
| MySQL | 8.0 | `apt install mysql-server` |
| Redis | 7.0 | `apt install redis-server` |
| Docker | 未安装 | 基础设施服务在用户空间手动运行 |

---

## 第一步：安装缺失依赖

### Maven

系统未预装 Maven，且 `sudo apt install maven` 需要交互式终端密码，无法在 Claude Code 内执行。

**解决**：从 Apache 归档站下载二进制包，解压到用户目录：

```bash
curl -sL "https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz" -o /tmp/maven.tar.gz
tar xzf /tmp/maven.tar.gz -C /home/susan/.local/
mv /home/susan/.local/apache-maven-3.9.9 /home/susan/.local/maven
```

使用时需将 `~/.local/maven/bin` 加入 `PATH`。

### pnpm

```bash
npm install -g pnpm
```

---

## 第二步：配置 .env 环境变量

```bash
cp .env.example .env
```

### 修改的关键配置项

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `SPRING_DATASOURCE_PASSWORD` | `PaiSmart2025` | MySQL root 密码 |
| `SPRING_DATA_REDIS_PASSWORD` | (空) | Redis 未设置密码，留空 |
| `MINIO_ACCESS_KEY` | `admin` | MinIO 访问密钥 |
| `MINIO_SECRET_KEY` | `PaiSmart2025` | MinIO 密钥 |
| `ELASTICSEARCH_SCHEME` | `http` | 本地关闭 HTTPS |
| `ELASTICSEARCH_PASSWORD` | `PaiSmart2025` | ES 密码 |
| `JWT_SECRET_KEY` | `CM2KFWVQKlVvNAT7I7mtlHxQn3Twui+fYiOtTwU1/90=` | openssl 生成 |
| `ADMIN_BOOTSTRAP_ENABLED` | `true` | 首次创建管理员 |
| `ADMIN_BOOTSTRAP_PASSWORD` | `PaiSmart2025!` | 需 ≥12 位 |
| `KNOWLEDGE_BOOTSTRAP_ENABLED` | `false` | 暂时关闭（需 lit CLI） |

### 遇到的问题

| 问题 | 解决方法 |
|------|----------|
| **管理员密码长度校验失败** (`admin.bootstrap.password 长度必须 >= 12`) | 原设 `admin123`（8位），改为 `PaiSmart2025!`（13位） |
| **Redis 密码不匹配** | `.env` 原设密码 `PaiSmart2025`，但 Redis 默认无密码，改为空 |
| **Bootstrap Knowledge 启动崩溃** | 缺少 `lit` (LiteParse CLI) 导致文档导入失败，设置 `KNOWLEDGE_BOOTSTRAP_ENABLED=false` 跳过 |

---

## 第三步：启动基础设施服务

基础设施服务（MySQL/Redis/Kafka/MinIO/Elasticsearch）无法直接使用项目自带的 `infra.sh`，因为脚本中硬编码了 macOS 路径 (`/Users/itwanger/Downloads/...`)。Docker 也未安装。

### MySQL & Redis

用户在自己的 WSL2 终端中执行：

```bash
sudo apt-get update && sudo apt-get install -y mysql-server redis-server
```

#### MySQL 初始化

```bash
sudo mysql -e "
  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'PaiSmart2025';
  CREATE DATABASE IF NOT EXISTS PaiSmart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  FLUSH PRIVILEGES;
"
```

### MinIO / Kafka / Elasticsearch

这三个服务在用户空间下载运行（存放于 `.runtime/services/`）：

```bash
RUNTIME=.runtime/services
mkdir -p $RUNTIME

# MinIO（Go 二进制）
curl -sL https://dl.min.io/server/minio/release/linux-amd64/minio -o $RUNTIME/minio
chmod +x $RUNTIME/minio

# Kafka 3.9.0
curl -sL https://archive.apache.org/dist/kafka/3.9.0/kafka_2.13-3.9.0.tgz -o /tmp/kafka.tgz
tar xzf /tmp/kafka.tgz -C $RUNTIME && mv $RUNTIME/kafka_2.13-3.9.0 $RUNTIME/kafka

# Elasticsearch 8.10.4
curl -sL https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.10.4-linux-x86_64.tar.gz -o /tmp/es.tar.gz
tar xzf /tmp/es.tar.gz -C $RUNTIME && mv $RUNTIME/elasticsearch-8.10.4 $RUNTIME/elasticsearch
```

#### 启动参数

- **MinIO**：关闭 HTTPS，根用户 `admin/PaiSmart2025`，控制台 `:9001`
- **Kafka**：KRaft 模式（无需 ZooKeeper），监听 `:9092`
- **Elasticsearch**：关闭 X-Pack Security，单节点模式，HTTP 访问，限制内存 512MB

### 遇到的问题

| 问题 | 解决方法 |
|------|----------|
| **`infra.sh` 路径不兼容** | 脚本使用 macOS 路径 `/Users/itwanger/...`，Linux/WSL2 不可用。改为手动下载二进制到 `.runtime/services/` |
| **Docker 未安装且无法 sudo** | 全部基础设施服务改用用户空间手动运行 |
| **ES 缺少 IK 中文分词插件** | 后端启动时 ES 索引初始化失败（`analyzer [ik_smart] has not been configured`）。执行 `elasticsearch-plugin install analysis-ik` 安装后重启 ES |
| **ES 旧进程残留** | `pkill -9 -f elasticsearch` 清理后重新启动 |
| **MinIO bucket 不存在** | 后端因 `The specified bucket does not exist` 崩溃。下载 MinIO Client (`mc`)，配置 alias 后 `mc mb myminio/uploads` 创建 bucket |

---

## 第四步：启动后端

```bash
export PATH="/home/susan/.local/maven/bin:$PATH"
cd /home/susan/MySpace/codeSpace/shixun/PaiSmart
nohup mvn spring-boot:run > .runtime/logs/backend.log 2>&1 &
```

- 首次启动耗时约 5 分钟（Maven 下载依赖）
- 后续启动约 7-20 秒
- 监听端口：**8081**

### 验证

```bash
grep "Started SmartPaiApplication" .runtime/logs/backend.log
# Started SmartPaiApplication in 7.167 seconds
```

---

## 第五步：启动前端

```bash
cd frontend
pnpm install
pnpm run dev
```

- 框架：Vue 3 + TypeScript + Vite 6
- 监听端口：**9527**（由 `frontend/.env.test` 配置）
- 启动时间：约 3 秒

### 遇到的问题

| 问题 | 解决方法 |
|------|----------|
| **`@iconify/utils` ESM 解析失败** | Node.js v22 严格 ESM 模式下，`build/plugins/unocss.ts` 中 `import from '@iconify/utils/lib/loader/node-loaders'` 缺少扩展名。修改为 `node-loaders.mjs` |
| **pnpm 忽略构建脚本** | `pnpm approve-builds @parcel/watcher esbuild simple-git-hooks vue-demi` 后重新 `pnpm install` |
| **`@iconify/utils` 未 hoist** | 虽然 `.npmrc` 设了 `shamefully-hoist=true`，但该包未被提升到顶层 `node_modules`。手动创建软链接：`ln -sf ../.pnpm/@iconify+utils@2.3.0/node_modules/@iconify/utils node_modules/@iconify/utils` |

---

## 最终部署状态

```
╔══════════════════════════════════════════╗
║     PaiSmart 部署完成                   ║
╠══════════════════════════════════════════╣

  基础设施:
  ✅ MySQL                :3306
  ✅ Redis                :6379
  ✅ Kafka                :9092
  ✅ MinIO                :9000
  ✅ Elasticsearch        :9200

  应用:
  ✅ SpringBoot 后端       :8081
  ✅ Vue3 前端             :9527

╠══════════════════════════════════════════╣
  🌐 前端:    http://localhost:9527/
  🔌 后端API: http://localhost:8081/api/v1/
  📦 MinIO:   http://localhost:9001/
╚══════════════════════════════════════════╝
```

---

## 账号与密码汇总

| 用途 | 用户名 | 密码 | 说明 |
|------|--------|------|------|
| **PaiSmart 管理员** | `admin` | `PaiSmart2025!` | Web 登录 |
| **MySQL** | `root` | `PaiSmart2025` | 数据库 `PaiSmart` |
| **Redis** | — | (无密码) | 本地 `:6379` |
| **MinIO** | `admin` | `PaiSmart2025` | API `:9000` / Console `:9001` |
| **Elasticsearch** | `elastic` | `PaiSmart2025` | HTTP `:9200`（安全已关闭） |
| **Kafka** | — | (无认证) | `:9092` |

---

## 待配置项

以下功能需要有效的 API Key 才能使用，在 `.env` 中配置：

| 配置项 | 用途 | 获取地址 |
|--------|------|----------|
| `DEEPSEEK_API_KEY` | AI 对话（DeepSeek） | https://platform.deepseek.com |
| `EMBEDDING_API_KEY` | 文档向量化（阿里云 DashScope） | https://dashscope.aliyun.com |
| `FILE_PARSING_LITEPARSE_COMMAND` | PDF 解析（LiteParse CLI） | `npm install -g @llamaindex/liteparse` |

配置后需要将 `.env` 中 `KNOWLEDGE_BOOTSTRAP_ENABLED` 改回 `true` 以启用知识库文档自动导入。

---

## 项目修改记录

为适配当前环境，以下文件被修改：

| 文件 | 修改内容 |
|------|----------|
| `.env` | 从 `.env.example` 复制并填写所有配置 |
| `frontend/build/plugins/unocss.ts` | 修复 `@iconify/utils` ESM 导入路径（添加 `.mjs` 扩展名） |
| `frontend/node_modules/@iconify/utils` | 创建软链接解决 pnpm hoist 问题 |
