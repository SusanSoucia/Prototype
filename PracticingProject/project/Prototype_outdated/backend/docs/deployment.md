# 企业知识问答系统部署说明文档

## 1. 部署帮助软件

### 1.1 SSH 连接工具

用于远程登录 Linux 服务器并执行部署命令，可任选其一：

- XShell
- FinalShell
- SecureCRT
- macOS / Linux 自带 Terminal

### 1.2 文件传输工具

用于上传后端 jar 包、`.env` 配置文件、数据库备份文件等：

- WinSCP
- FileZilla
- FinalShell 自带文件管理
- `scp` 命令

示例：

```bash
scp target/group45-backend-0.0.1-SNAPSHOT.jar root@服务器IP:/opt/group45/backend/
scp .env root@服务器IP:/opt/group45/backend/
```

## 2. 后端运行环境安装部署

### 2.1 安装信息

本项目后端为 Spring Boot 可执行 jar 包，部署时需要准备以下环境：

| 项目 | 推荐版本 | 用途 |
| --- | --- | --- |
| 操作系统 | CentOS 7/8、Ubuntu 22.04 或同类 Linux | 后端服务运行环境 |
| JDK | 17 | 运行 Spring Boot 后端 |
| Maven | 3.9 或以上 | 构建 jar 包 |
| MySQL | 8.x | 业务数据存储 |
| Redis | 6.x/7.x | 登录、限流、会话和缓存 |
| Kafka | 3.x | 文件上传后的异步解析任务 |
| MinIO | RELEASE.2024 或同类稳定版本 | 原始文件对象存储 |
| Elasticsearch | 8.10.x | 文档向量和检索索引 |
| LiteParse | 可执行命令 `lit` | PDF 解析 |

后端默认监听端口为 `8081`，生产环境通过 `SERVER_PORT` 覆盖。

### 2.2 安装 JDK 17 和 Maven

在服务器上安装 JDK 17：

```bash
java -version
```

确认输出包含 `17`。如果未安装，可按服务器系统选择安装方式。

CentOS 示例：

```bash
sudo yum install -y java-17-openjdk java-17-openjdk-devel
```

Ubuntu 示例：

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
```

如果需要在服务器上直接打包项目，还需安装 Maven：

```bash
mvn -version
```

## 3. MySQL 数据库安装部署

### 3.1 安装信息

| 项目 | 说明 |
| --- | --- |
| 数据库类型 | MySQL |
| 推荐版本 | 8.x |
| 默认库名 | `group45_db` |
| 字符集 | `utf8mb4` |
| 排序规则 | `utf8mb4_unicode_ci` |

### 3.2 创建数据库和用户

登录 MySQL：

```bash
mysql -uroot -p
```

创建数据库：

```sql
CREATE DATABASE IF NOT EXISTS group45_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
```

建议为项目单独创建账号：

```sql
CREATE USER 'group45'@'%' IDENTIFIED BY '请替换为强密码';
GRANT ALL PRIVILEGES ON group45_db.* TO 'group45'@'%';
FLUSH PRIVILEGES;
```

### 3.3 数据库初始化说明

当前后端使用 Spring Data JPA，生产配置中 `spring.jpa.hibernate.ddl-auto` 为 `update`，应用首次启动时会根据实体类自动维护表结构。

仓库已提供初始化脚本：

```text
docs/databases/ddl.sql
```

部署时可先执行：

```bash
mysql -uroot -p < docs/databases/ddl.sql
```

如果已有生产数据备份，可将 SQL 文件上传到服务器后导入：

```bash
mysql -ugroup45 -p group45_db < /opt/group45/data/group45_db_backup.sql
```

## 4. 后端依赖服务安装部署

### 4.1 Redis

Redis 用于缓存、限流、Token 状态和聊天生成状态。

安装后确认服务可访问：

```bash
redis-cli -h 127.0.0.1 -p 6379 ping
```

返回：

```text
PONG
```

对应后端配置：

```properties
SPRING_DATA_REDIS_HOST=127.0.0.1
SPRING_DATA_REDIS_PORT=6379
SPRING_DATA_REDIS_PASSWORD=
```

### 4.2 Kafka

Kafka 用于文件上传后的异步解析、向量化处理。应用启动时会自动创建以下 topic：

- `file-processing-topic1`
- `file-processing-dlt`

对应后端配置：

```properties
SPRING_KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:9092
SPRING_KAFKA_TOPIC_PARTITIONS=1
SPRING_KAFKA_TOPIC_REPLICATION_FACTOR=1
```

单机部署时分区数和副本数保持 `1` 即可；多节点生产环境可根据 Kafka 集群规模调整。

### 4.3 MinIO

MinIO 用于存储上传的原始文件，后端解析链路会读取 MinIO 中的对象。

需创建默认 bucket：

```bash
mc alias set local http://127.0.0.1:9000 minioadmin minioadmin
mc mb local/uploads
```

对应后端配置：

```properties
MINIO_ENDPOINT=http://127.0.0.1:9000
MINIO_PUBLIC_URL=http://服务器IP:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=请替换为强密码
MINIO_BUCKET_NAME=uploads
```

### 4.4 Elasticsearch

Elasticsearch 用于文档检索和向量索引，项目客户端依赖版本为 `elasticsearch-java 8.10.0`。

生产环境建议使用 HTTPS 并配置真实证书，不能开启跳过证书校验：

```properties
ELASTICSEARCH_HOST=127.0.0.1
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_SCHEME=https
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=请替换为真实密码
ELASTICSEARCH_INSECURE_TRUST_ALL_CERTIFICATES=false
ELASTICSEARCH_INIT_ENABLE=true
```

本地自签名证书调试时可以临时设为 `true`，但 `prod` profile 会禁止该配置。

### 4.5 LiteParse 和 OCR

后端 PDF 解析默认使用 LiteParse，命令名为 `lit`。服务器部署时建议写绝对路径，避免后台进程找不到命令：

```bash
which lit
```

配置示例：

```properties
FILE_PARSING_LITEPARSE_COMMAND=/usr/local/bin/lit
FILE_PARSING_LITEPARSE_OCR_ENABLED=false
FILE_PARSING_LITEPARSE_OCR_LANGUAGE=chi_sim
FILE_PARSING_LITEPARSE_DPI=300
```

如果需要识别扫描件或图片文字，可开启 OCR，并按实际方案配置 Tesseract 或阿里云 OCR：

```properties
ALIYUN_OCR_ENABLED=false
ALIYUN_OCR_ACCESS_KEY_ID=
ALIYUN_OCR_ACCESS_KEY_SECRET=
```

## 5. 后端应用程序打包部署

### 5.1 项目打包

后端项目名称：`group45-backend`

打包方式：Maven 生成 Spring Boot 可执行 jar。

在项目根目录执行：

```bash
mvn -DskipTests package
```

打包成功后生成：

```text
target/group45-backend-0.0.1-SNAPSHOT.jar
```

### 5.2 上传 jar 包到服务器

在服务器创建部署目录：

```bash
sudo mkdir -p /opt/group45/backend
sudo mkdir -p /opt/group45/backend/logs
```

上传 jar 包：

```bash
scp target/group45-backend-0.0.1-SNAPSHOT.jar root@服务器IP:/opt/group45/backend/
```

### 5.3 编写生产环境配置文件

在服务器 `/opt/group45/backend/.env` 中填写真实配置：

```properties
SPRING_PROFILES_ACTIVE=prod
APP_TIMEZONE=Asia/Shanghai
SERVER_PORT=8081

SPRING_DATASOURCE_URL=jdbc:mysql://127.0.0.1:3306/group45_db?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true
SPRING_DATASOURCE_USERNAME=group45
SPRING_DATASOURCE_PASSWORD=请替换为数据库密码

SPRING_DATA_REDIS_HOST=127.0.0.1
SPRING_DATA_REDIS_PORT=6379
SPRING_DATA_REDIS_PASSWORD=

SPRING_KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:9092
SPRING_KAFKA_TOPIC_PARTITIONS=1
SPRING_KAFKA_TOPIC_REPLICATION_FACTOR=1

MINIO_ENDPOINT=http://127.0.0.1:9000
MINIO_PUBLIC_URL=http://服务器IP:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=请替换为MinIO密码
MINIO_BUCKET_NAME=uploads

ELASTICSEARCH_HOST=127.0.0.1
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_SCHEME=https
ELASTICSEARCH_USERNAME=elastic
ELASTICSEARCH_PASSWORD=请替换为Elasticsearch密码
ELASTICSEARCH_INSECURE_TRUST_ALL_CERTIFICATES=false

JWT_SECRET_KEY=请替换为openssl-rand-base64-32输出

ADMIN_BOOTSTRAP_ENABLED=true
ADMIN_BOOTSTRAP_USERNAME=admin
ADMIN_BOOTSTRAP_PASSWORD=请替换为管理员初始密码
ADMIN_BOOTSTRAP_PRIMARY_ORG=default
ADMIN_BOOTSTRAP_ORG_TAGS=default,admin

SECURITY_ALLOWED_ORIGINS=https://前端域名,http://服务器IP:前端端口

DEEPSEEK_API_URL=https://api.deepseek.com/v1
DEEPSEEK_API_MODEL=deepseek-chat
DEEPSEEK_API_KEY=请替换为真实Key

EMBEDDING_API_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
EMBEDDING_API_MODEL=text-embedding-v4
EMBEDDING_API_KEY=请替换为真实Key

LOG_LEVEL_APP=INFO

FILE_PARSING_LITEPARSE_COMMAND=/usr/local/bin/lit
FILE_PARSING_LITEPARSE_OCR_ENABLED=false
FILE_PARSING_LITEPARSE_OCR_LANGUAGE=chi_sim
FILE_PARSING_LITEPARSE_DPI=300
```

`JWT_SECRET_KEY` 可在服务器上生成：

```bash
openssl rand -base64 32
```

首次启动创建管理员账号后，应将：

```properties
ADMIN_BOOTSTRAP_ENABLED=false
```

并重启后端，避免重复执行初始化逻辑。

### 5.4 后台运行 jar 包

进入部署目录：

```bash
cd /opt/group45/backend
```

后台启动：

```bash
nohup java -jar group45-backend-0.0.1-SNAPSHOT.jar > logs/backend.log 2>&1 &
```

查看进程：

```bash
ps -ef | grep group45-backend
```

查看日志：

```bash
tail -f logs/backend.log
```

### 5.5 使用 systemd 管理服务

生产环境建议使用 systemd 托管后端服务。

创建服务文件：

```bash
sudo vi /etc/systemd/system/group45-backend.service
```

写入：

```ini
[Unit]
Description=Group45 Enterprise QA Backend
After=network.target mysql.service redis.service

[Service]
Type=simple
WorkingDirectory=/opt/group45/backend
EnvironmentFile=/opt/group45/backend/.env
ExecStart=/usr/bin/java -jar /opt/group45/backend/group45-backend-0.0.1-SNAPSHOT.jar
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable group45-backend
sudo systemctl start group45-backend
```

查看状态和日志：

```bash
sudo systemctl status group45-backend
journalctl -u group45-backend -f
```

## 6. Nginx 后端反向代理配置

如果只部署后端接口，可使用 Nginx 将 `/api/` 和 `/chat/` 转发到后端。

示例配置：

```nginx
server {
    listen 80;
    server_name example.com;

    location /api/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /chat/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

检查配置并重载：

```bash
sudo nginx -t
sudo nginx -s reload
```

## 7. 前端项目部署流程

### 7.1 前期配置

前端项目位于：

```text
/Users/linkw/foolish class/group45-frontend
```

前端技术栈为 Vue3、Vite、TypeScript、Naive UI 和 pnpm workspace。生产环境打包前需要检查 `group45-frontend/.env.prod`。

当前 `.env.prod` 中的后端地址仍是 Apifox mock：

```properties
VITE_SERVICE_BASE_URL=https://mock.apifox.cn/m1/3109515-0-default
```

正式部署前必须改为真实后端地址。推荐同域名反向代理方式：

```properties
VITE_SERVICE_BASE_URL=/api/v1
VITE_OTHER_SERVICE_BASE_URL= `{
  "demo": "http://localhost:9529",
  "ws": "/"
}`
```

说明：

- REST 接口通过 `/api/v1` 访问后端。
- 聊天 WebSocket 在代码中使用 `/proxy-ws/chat/{token}`，需要由 Nginx 转发到后端 `/chat/{token}`。
- 如果前端和后端使用不同域名，需要同时修改后端 `.env` 中的 `SECURITY_ALLOWED_ORIGINS`。

### 7.2 安装 Node.js 和 pnpm

前端 `package.json` 要求：

| 项目 | 版本要求 |
| --- | --- |
| Node.js | `>=20.19.0` |
| pnpm | `>=10.5.0` |

检查版本：

```bash
node -v
pnpm -v
```

如果服务器没有 pnpm，可安装：

```bash
npm install -g pnpm
```

### 7.3 安装依赖

进入前端项目目录：

```bash
cd /opt/group45/frontend-source
```

安装依赖：

```bash
pnpm install --frozen-lockfile
```

如果因本机 pnpm 版本差异导致 lockfile 校验失败，可先在开发机完成构建，再只上传构建后的 `dist` 目录到服务器。

### 7.4 项目打包

生产环境打包命令：

```bash
pnpm build
```

该命令实际执行：

```bash
vite build --mode prod
```

打包成功后生成：

```text
dist/
```

### 7.5 部署到服务器

创建前端站点目录：

```bash
sudo mkdir -p /opt/group45/frontend
```

上传 `dist` 目录内容：

```bash
scp -r dist/* root@服务器IP:/opt/group45/frontend/
```

如果使用 Nginx 托管静态文件，站点根目录应指向：

```text
/opt/group45/frontend
```

## 8. Nginx 前后端统一访问配置

生产环境推荐使用同一域名提供前端页面、REST API 和 WebSocket。这样浏览器只访问一个域名，部署更稳定，也能减少跨域问题。

完整示例：

```nginx
server {
    listen 80;
    server_name example.com;

    root /opt/group45/frontend;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /proxy-ws/ {
        proxy_pass http://127.0.0.1:8081/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

配置说明：

- `/`：返回前端静态页面。
- `/api/`：转发到后端 REST 接口，例如 `/api/v1/users/login`。
- `/proxy-ws/`：转发到后端 WebSocket，例如 `/proxy-ws/chat/{token}` 转成 `/chat/{token}`。
- `try_files $uri $uri/ /index.html`：支持 Vue history 路由刷新不 404。

检查配置并重载：

```bash
sudo nginx -t
sudo nginx -s reload
```

## 9. 部署后验证

### 9.1 后端端口检查

```bash
ss -lntp | grep 8081
```

### 9.2 登录接口验证

使用初始化管理员账号登录：

```bash
curl -X POST http://127.0.0.1:8081/api/v1/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "请替换为管理员初始密码"
  }'
```

正常返回中应包含：

```json
{
  "code": 200,
  "message": "Login successful",
  "data": {
    "token": "...",
    "refreshToken": "..."
  }
}
```

### 9.3 管理端状态接口验证

将上一步返回的 token 放入请求头：

```bash
curl -X GET http://127.0.0.1:8081/api/v1/admin/system/status \
  -H "Authorization: Bearer 后端返回的token"
```

如果接口返回系统状态信息，说明后端接口、JWT 和管理员权限链路可用。

### 9.4 前端页面验证

浏览器访问：

```text
http://服务器IP/
```

或：

```text
http://example.com/
```

验证内容：

- 页面能正常加载。
- 刷新 `/chats`、`/knowledge-base`、`/org-tag` 等前端路由不出现 404。
- 登录请求发送到 `/api/v1/users/login`，不是 Apifox mock 地址。
- 聊天页面 WebSocket 请求为 `/proxy-ws/chat/{token}`，状态码为 `101 Switching Protocols`。

### 9.5 文件上传链路验证

确认以下服务均已正常连接：

- MySQL：业务表可自动创建或访问
- Redis：限流和缓存无连接异常
- Kafka：文件处理 topic 可自动创建
- MinIO：`uploads` bucket 可访问
- Elasticsearch：索引初始化成功
- LiteParse：日志中没有 `lit` 命令找不到的错误

## 10. 稳定运行配置

### 10.1 后端进程托管

生产环境不要长期依赖手动 `nohup`，建议使用 systemd：

```bash
sudo systemctl enable group45-backend
sudo systemctl restart group45-backend
sudo systemctl status group45-backend
```

后端异常退出后，`Restart=always` 会自动拉起服务。

### 10.2 日志查看

systemd 日志：

```bash
journalctl -u group45-backend -f
```

如果使用 `nohup`：

```bash
tail -f /opt/group45/backend/logs/backend.log
```

需要重点关注以下错误：

- MySQL `Connection refused` 或认证失败。
- Redis 连接失败。
- Kafka bootstrap server 连接失败。
- MinIO bucket 不存在或认证失败。
- Elasticsearch SSL、用户名密码或索引初始化失败。
- LiteParse 命令不存在或 OCR 语言包缺失。

### 10.3 开机自启动

确认后端服务已设置开机自启：

```bash
systemctl is-enabled group45-backend
```

确认 Nginx 已设置开机自启：

```bash
systemctl is-enabled nginx
```

### 10.4 服务重启顺序

服务器重启或依赖服务维护后，建议顺序为：

1. MySQL
2. Redis
3. Kafka
4. MinIO
5. Elasticsearch
6. 后端 `group45-backend`
7. Nginx

后端启动前必须保证 MySQL、Redis、Kafka、MinIO、Elasticsearch 已可访问。

### 10.5 配置变更后的重启

修改后端 `.env` 后：

```bash
sudo systemctl restart group45-backend
```

修改 Nginx 配置后：

```bash
sudo nginx -t
sudo nginx -s reload
```

修改前端 `.env.prod` 后，需要重新构建并重新上传 `dist`，仅重启 Nginx 不会生效：

```bash
pnpm build
scp -r dist/* root@服务器IP:/opt/group45/frontend/
```

### 10.6 稳定性检查清单

| 检查项 | 命令或位置 | 正常结果 |
| --- | --- | --- |
| 后端进程 | `systemctl status group45-backend` | `active (running)` |
| 后端端口 | `ss -lntp \| grep 8081` | 监听 `8081` |
| Nginx 配置 | `nginx -t` | `syntax is ok` |
| MySQL | `mysql -ugroup45 -p group45_db` | 可登录并访问库 |
| Redis | `redis-cli ping` | `PONG` |
| Kafka | 查看后端日志 | topic 创建和消费无异常 |
| MinIO | MinIO 控制台或 `mc ls local/uploads` | bucket 可访问 |
| Elasticsearch | `curl -k -u elastic:密码 https://127.0.0.1:9200` | 返回集群信息 |
| REST API | `curl /api/v1/users/login` | 返回业务 JSON |
| WebSocket | 浏览器 Network | `/proxy-ws/chat/{token}` 握手成功 |

## 11. 常见问题处理

### 11.1 启动时报缺少生产配置

`prod` profile 会校验关键配置。如果日志出现：

```text
Missing required production config
```

需要检查 `.env` 中是否缺少数据库密码、JWT、模型 Key、MinIO、Elasticsearch 或前端来源白名单。

### 11.2 Elasticsearch 证书错误

生产环境要求：

```properties
ELASTICSEARCH_INSECURE_TRUST_ALL_CERTIFICATES=false
```

如果使用 HTTPS 自签证书，需要把证书导入 JVM 信任链，不能在生产环境开启跳过证书校验。

### 11.3 Kafka 连接失败

检查配置：

```properties
SPRING_KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:9092
```

如果后端运行在 Docker 容器中，地址通常不能写 `127.0.0.1`，应改为 Kafka 服务名或容器网络地址。

### 11.4 LiteParse 命令找不到

后台运行和 systemd 启动时 PATH 可能不同。建议使用绝对路径：

```properties
FILE_PARSING_LITEPARSE_COMMAND=/usr/local/bin/lit
```

### 11.5 管理员初始化后仍无法登录

检查首次启动时是否设置：

```properties
ADMIN_BOOTSTRAP_ENABLED=true
ADMIN_BOOTSTRAP_USERNAME=admin
ADMIN_BOOTSTRAP_PASSWORD=强密码
```

确认账号创建成功后，将 `ADMIN_BOOTSTRAP_ENABLED` 改回 `false` 并重启服务。

### 11.6 前端部署后仍请求 Apifox

原因通常是 `.env.prod` 没有改，或者改完后没有重新执行 `pnpm build`。

处理方式：

```properties
VITE_SERVICE_BASE_URL=/api/v1
```

然后重新构建并上传 `dist`。

### 11.7 前端刷新页面 404

Nginx 缺少 history 路由回退配置。需要确认：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### 11.8 WebSocket 连接失败

确认 Nginx 有 `/proxy-ws/` 转发，并包含：

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

同时确认后端 `.env` 的 `SECURITY_ALLOWED_ORIGINS` 包含前端域名。
