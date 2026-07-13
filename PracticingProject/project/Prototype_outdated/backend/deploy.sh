#!/usr/bin/env bash
# =============================================================================
# Group45 Backend — 傻瓜式部署脚本 (Linux / macOS)
# =============================================================================
# 用法:
#   chmod +x deploy.sh
#   ./deploy.sh              # 交互式引导部署
#   ./deploy.sh infra-up     # 一键启动 Docker 基础设施 (MySQL/Redis/ES/Kafka/MinIO)
#   ./deploy.sh infra-down   # 停止并销毁 Docker 基础设施
#   ./deploy.sh infra-status # 查看 Docker 容器状态
#   ./deploy.sh build        # 只编译
#   ./deploy.sh start        # 编译 + 前台启动
#   ./deploy.sh start-bg     # 编译 + 后台启动
#   ./deploy.sh stop         # 停止后台进程
#   ./deploy.sh status       # 查看服务状态
#   ./deploy.sh help         # 显示帮助
# =============================================================================

set -euo pipefail

# ------------------------------ 颜色定义 ------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ------------------------------ 路径定义 ------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR"
ENV_FILE="$BACKEND_DIR/.env"
ENV_EXAMPLE="$BACKEND_DIR/.env.example"
PID_DIR="$BACKEND_DIR/.runtime/pids"
LOG_DIR="$BACKEND_DIR/logs"
PID_FILE="$PID_DIR/app.pid"
APP_LOG="$LOG_DIR/app.log"
COMPOSE_FILE="$BACKEND_DIR/../docs/docker-compose.yaml"

# ------------------------------ 工具函数 ------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo -e "${CYAN}${BOLD}  Group45 Backend — 部署脚本${NC}"
    echo -e "${CYAN}${BOLD}============================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

print_ok() {
    echo -e "    ${GREEN}✓${NC} $1"
}

print_warn() {
    echo -e "    ${YELLOW}⚠${NC} $1"
}

print_err() {
    echo -e "    ${RED}✗${NC} $1"
}

print_tip() {
    echo -e "    ${CYAN}💡 $1${NC}"
}

# ------------------------------ 环境检测 ------------------------------------
check_java() {
    print_step "检测 Java 环境..."

    if ! command -v java &>/dev/null; then
        print_err "未找到 java 命令，请先安装 JDK 17+"
        echo ""
        echo "  Ubuntu/Debian: sudo apt install openjdk-17-jdk"
        echo "  CentOS/RHEL:   sudo yum install java-17-openjdk-devel"
        echo "  macOS:         brew install openjdk@17"
        echo "  通用:          从 https://adoptium.net 下载安装"
        echo ""
        exit 1
    fi

    local java_version
    java_version=$(java -version 2>&1 | head -1 | grep -oP '\d+' | head -1 || echo "0")
    print_ok "java 已安装 (主版本: $java_version)"

    if [[ "$java_version" -lt 17 ]]; then
        print_err "Java 版本过低 ($java_version)，需要 JDK 17+"
        exit 1
    fi
}

check_maven() {
    print_step "检测 Maven 环境..."

    # 优先使用项目自带的 mvnw
    if [[ -f "$BACKEND_DIR/mvnw" ]]; then
        MVN_CMD="$BACKEND_DIR/mvnw"
        print_ok "使用项目自带的 Maven Wrapper (mvnw)"
        return
    fi

    if ! command -v mvn &>/dev/null; then
        print_err "未找到 mvn 命令，请先安装 Maven 3.9+"
        echo ""
        echo "  Ubuntu/Debian: sudo apt install maven"
        echo "  macOS:         brew install maven"
        echo "  通用:          从 https://maven.apache.org 下载"
        echo ""
        exit 1
    fi

    MVN_CMD="mvn"
    print_ok "mvn 已安装: $(mvn --version 2>&1 | head -1)"
}

check_env_file() {
    print_step "检查配置文件..."

    if [[ -f "$ENV_FILE" ]]; then
        print_ok ".env 文件已存在"
    else
        print_warn ".env 文件不存在，正在从 .env.example 复制..."
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        print_ok "已创建 .env 文件"
        echo ""
        echo -e "  ${YELLOW}${BOLD}⚠ 重要：请先编辑 .env 文件，填入真实的配置信息！${NC}"
        echo ""
        echo -e "  必须修改的核心配置项:"
        echo -e "  ${CYAN}  - DEEPSEEK_API_KEY          (LLM API Key)${NC}"
        echo -e "  ${CYAN}  - EMBEDDING_API_KEY         (向量服务 API Key)${NC}"
        echo -e "  ${CYAN}  - SPRING_DATASOURCE_PASSWORD (MySQL 密码)${NC}"
        echo -e "  ${CYAN}  - ELASTICSEARCH_PASSWORD     (ES 密码)${NC}"
        echo ""
        read -r -p "  是否现在编辑 .env 文件？(y/n) " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            ${EDITOR:-vim} "$ENV_FILE"
        else
            echo ""
            print_warn "请手动编辑 $ENV_FILE 后再运行部署"
        fi
    fi
}

check_infrastructure() {
    print_step "检测基础设施连接..."

    local env_vars
    # 加载 .env 文件（简单解析，不覆盖已有环境变量）
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$' | sed 's/^export //')
        set +a
    fi

    # MySQL
    local mysql_host=$(echo "${SPRING_DATASOURCE_URL:-}" | sed -n 's/.*:\/\/\([^:/]*\).*/\1/p')
    local mysql_port=$(echo "${SPRING_DATASOURCE_URL:-}" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    mysql_port="${mysql_port:-3306}"
    if [[ -n "$mysql_host" ]]; then
        if timeout 2 bash -c "echo >/dev/tcp/$mysql_host/$mysql_port" 2>/dev/null; then
            print_ok "MySQL 可达 ($mysql_host:$mysql_port)"
        else
            print_warn "MySQL 不可达 ($mysql_host:$mysql_port)，请确认服务已启动"
        fi
    fi

    # Redis
    local redis_host="${SPRING_DATA_REDIS_HOST:-localhost}"
    local redis_port="${SPRING_DATA_REDIS_PORT:-6379}"
    if timeout 2 bash -c "echo >/dev/tcp/$redis_host/$redis_port" 2>/dev/null; then
        print_ok "Redis 可达 ($redis_host:$redis_port)"
    else
        print_warn "Redis 不可达 ($redis_host:$redis_port)，请确认服务已启动"
    fi

    # Elasticsearch
    local es_host="${ELASTICSEARCH_HOST:-localhost}"
    local es_port="${ELASTICSEARCH_PORT:-9200}"
    if timeout 2 bash -c "echo >/dev/tcp/$es_host/$es_port" 2>/dev/null; then
        print_ok "Elasticsearch 可达 ($es_host:$es_port)"
    else
        print_warn "Elasticsearch 不可达 ($es_host:$es_port)，请确认服务已启动"
    fi

    # Kafka
    local kafka_server="${SPRING_KAFKA_BOOTSTRAP_SERVERS:-127.0.0.1:9092}"
    local kafka_host=$(echo "$kafka_server" | cut -d: -f1)
    local kafka_port=$(echo "$kafka_server" | cut -d: -f2)
    if timeout 2 bash -c "echo >/dev/tcp/$kafka_host/$kafka_port" 2>/dev/null; then
        print_ok "Kafka 可达 ($kafka_server)"
    else
        print_warn "Kafka 不可达 ($kafka_server)，请确认服务已启动"
    fi

    # MinIO
    local minio_url="${MINIO_ENDPOINT:-http://localhost:9000}"
    local minio_host=$(echo "$minio_url" | sed -n 's|.*://\([^:/]*\).*|\1|p')
    local minio_port=$(echo "$minio_url" | sed -n 's|.*:\([0-9]*\).*|\1|p')
    minio_port="${minio_port:-9000}"
    if timeout 2 bash -c "echo >/dev/tcp/$minio_host/$minio_port" 2>/dev/null; then
        print_ok "MinIO 可达 ($minio_host:$minio_port)"
    else
        print_warn "MinIO 不可达 ($minio_host:$minio_port)，请确认服务已启动"
    fi
}

check_liteparse() {
    print_step "检测 LiteParse (PDF 解析工具)..."

    if command -v lit &>/dev/null; then
        print_ok "lit 命令可用: $(which lit)"
    elif command -v lite &>/dev/null; then
        print_ok "lite 命令可用: $(which lite)"
    else
        print_warn "liteparse 未安装（PDF 解析功能将不可用）"
        print_tip "安装方法: pip install 'mineru[core]' 详见 https://github.com/opendatalab/MinerU"
    fi
}

# ------------------------------ Docker 基础设施 -------------------------------
check_docker() {
    if ! command -v docker &>/dev/null; then
        print_err "未找到 Docker，请先安装 Docker"
        echo ""
        echo "  Linux:   curl -fsSL https://get.docker.com | sh"
        echo "  macOS:   brew install docker 或下载 Docker Desktop"
        echo "  Windows: 下载 Docker Desktop https://www.docker.com/products/docker-desktop"
        echo ""
        exit 1
    fi

    if ! docker info &>/dev/null; then
        print_err "Docker 未运行，请先启动 Docker Desktop 或 dockerd 服务"
        exit 1
    fi

    print_ok "Docker 已就绪"

    if ! command -v docker &>/dev/null; then
        # 检查 docker compose (v2) 子命令是否可用
        print_err "Docker Compose 不可用"
        exit 1
    fi
}

do_infra_up() {
    print_header
    print_step "一键启动 Docker 基础设施..."

    check_docker

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_err "找不到 docker-compose 文件: $COMPOSE_FILE"
        exit 1
    fi

    print_ok "使用配置: $COMPOSE_FILE"
    echo ""
    echo "  即将启动以下服务:"
    echo "  - MySQL 8.0       (端口 3306, root/prototype2025, 库 prototype_db)"
    echo "  - Redis 7          (端口 6379, 密码 prototype2025)"
    echo "  - Kafka (KRaft)    (端口 9092, 无需 ZooKeeper)"
    echo "  - Elasticsearch 8  (端口 9200, elastic/prototype2025, HTTP 无 SSL)"
    echo "  - MinIO            (端口 9000/9001, minioadmin/minioadmin)"
    echo ""

    cd "$(dirname "$COMPOSE_FILE")"
    docker compose -f "$(basename "$COMPOSE_FILE")" up -d

    echo ""
    print_step "等待所有容器健康检查通过..."

    # 等待并显示状态
    local waited=0
    local max_wait=120
    while [[ $waited -lt $max_wait ]]; do
        local all_healthy=true
        local status_output
        status_output=$(docker compose -f "$(basename "$COMPOSE_FILE")" ps --format json 2>/dev/null || true)

        if [[ -z "$status_output" ]]; then
            sleep 2
            ((waited+=2))
            continue
        fi

        while IFS= read -r line; do
            local health=$(echo "$line" | grep -o '"Health":"[^"]*"' | cut -d'"' -f4)
            local name=$(echo "$line" | grep -o '"Name":"[^"]*"' | cut -d'"' -f4)
            local state=$(echo "$line" | grep -o '"State":"[^"]*"' | cut -d'"' -f4)

            if [[ "$health" != "healthy" && "$name" != "prototype-minio-init" ]]; then
                all_healthy=false
            fi
        done <<< "$status_output"

        if $all_healthy; then
            echo ""
            print_ok "所有基础设施已就绪！"
            echo ""
            do_infra_status
            echo ""
            print_tip "现在可以运行: ./deploy.sh start-bg"
            return 0
        fi

        sleep 3
        ((waited+=3))
        echo -n "."
    done

    echo ""
    print_warn "等待超时，请手动检查: docker compose -f $COMPOSE_FILE ps"
    print_tip "部分服务可能仍在初始化中（首次拉取镜像较慢），稍后会自动就绪"
}

do_infra_down() {
    print_step "停止 Docker 基础设施..."

    check_docker

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_err "找不到 docker-compose 文件: $COMPOSE_FILE"
        exit 1
    fi

    cd "$(dirname "$COMPOSE_FILE")"

    echo ""
    echo "  选择操作:"
    echo "  1) 停止容器（保留数据卷，下次 infra-up 恢复数据）"
    echo "  2) 停止并销毁（⚠ 删除所有数据卷，不可恢复！）"
    echo ""
    read -r -p "  请输入选项 (1/2) [默认: 1]: " choice
    choice="${choice:-1}"

    case "$choice" in
        1)
            docker compose -f "$(basename "$COMPOSE_FILE")" stop
            print_ok "容器已停止，数据卷保留"
            ;;
        2)
            read -r -p "  确认删除所有数据？输入 yes 继续: " confirm
            if [[ "$confirm" == "yes" ]]; then
                docker compose -f "$(basename "$COMPOSE_FILE")" down -v
                print_ok "容器已销毁，数据卷已删除"
            else
                print_warn "已取消"
            fi
            ;;
        *) print_err "无效选项" ;;
    esac
}

do_infra_status() {
    print_step "Docker 基础设施状态..."

    check_docker

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        print_err "找不到 docker-compose 文件: $COMPOSE_FILE"
        return 1
    fi

    cd "$(dirname "$COMPOSE_FILE")"
    echo ""
    docker compose -f "$(basename "$COMPOSE_FILE")" ps 2>/dev/null || {
        print_warn "没有运行中的容器，请先执行 infra-up"
    }
}

# ------------------------------ 编译 ----------------------------------------
do_build() {
    print_step "开始编译项目 (Maven)..."

    cd "$BACKEND_DIR"

    # 跳过测试以加快编译（生产部署前建议跑一次测试）
    if [[ "${SKIP_TESTS:-true}" == "true" ]]; then
        local maven_opts="-DskipTests"
        print_tip "跳过单元测试 (设置 SKIP_TESTS=false 可启用)"
    else
        local maven_opts=""
    fi

    if $MVN_CMD clean package $maven_opts -q; then
        print_ok "编译成功"

        # 找到生成的 jar 包
        local jar_file
        jar_file=$(find "$BACKEND_DIR/target" -maxdepth 1 -name "*.jar" ! -name "*sources*" ! -name "*javadoc*" 2>/dev/null | head -1)
        if [[ -n "$jar_file" ]]; then
            print_ok "产物: $(basename "$jar_file")"
            echo "$jar_file" > "$BACKEND_DIR/.runtime/last-build.txt"
        fi
    else
        print_err "编译失败！请检查日志"
        exit 1
    fi
}

# ------------------------------ 启动 ----------------------------------------
do_start() {
    local mode="${1:-foreground}"  # foreground | background

    print_step "启动应用..."

    cd "$BACKEND_DIR"

    # 确保运行时目录存在
    mkdir -p "$PID_DIR" "$LOG_DIR"

    # 检查是否已经在运行
    if [[ -f "$PID_FILE" ]]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            print_warn "应用已在运行中 (PID: $old_pid)"
            read -r -p "  是否重启？(y/n) " answer
            if [[ "$answer" =~ ^[Yy] ]]; then
                do_stop
            else
                return 0
            fi
        else
            # PID 文件存在但进程已死，清理
            rm -f "$PID_FILE"
        fi
    fi

    # 加载 .env
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$' | sed 's/^export //')
        set +a
    fi

    # 确定 JAR 文件
    local jar_file
    if [[ -f "$BACKEND_DIR/.runtime/last-build.txt" ]]; then
        jar_file=$(cat "$BACKEND_DIR/.runtime/last-build.txt")
    fi
    if [[ -z "${jar_file:-}" ]] || [[ ! -f "${jar_file:-}" ]]; then
        jar_file=$(find "$BACKEND_DIR/target" -maxdepth 1 -name "*.jar" ! -name "*sources*" ! -name "*javadoc*" 2>/dev/null | head -1)
    fi

    if [[ -z "${jar_file:-}" ]]; then
        print_err "未找到 JAR 文件，请先执行 build"
        exit 1
    fi

    local port="${SERVER_PORT:-8081}"
    local profile="${SPRING_PROFILES_ACTIVE:-dev}"

    echo ""
    echo -e "  ${BOLD}启动配置:${NC}"
    echo -e "  JAR      : $(basename "$jar_file")"
    echo -e "  端口     : $port"
    echo -e "  Profile  : $profile"
    echo ""

    if [[ "$mode" == "background" ]]; then
        # 后台启动
        nohup java -jar "$jar_file" \
            --spring.profiles.active="$profile" \
            >> "$APP_LOG" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_FILE"
        print_ok "应用已在后台启动 (PID: $pid)"
        print_tip "查看日志: tail -f $APP_LOG"
        print_tip "停止服务: ./deploy.sh stop"
    else
        # 前台启动
        print_ok "前台启动中... (按 Ctrl+C 停止)"
        echo ""
        exec java -jar "$jar_file" --spring.profiles.active="$profile"
    fi
}

# ------------------------------ 停止 ----------------------------------------
do_stop() {
    print_step "停止应用..."

    if [[ ! -f "$PID_FILE" ]]; then
        print_warn "未找到 PID 文件，尝试查找 Java 进程..."

        local pids
        pids=$(pgrep -f "group45-backend" 2>/dev/null || true)
        if [[ -z "$pids" ]]; then
            print_ok "没有运行中的进程"
            return 0
        fi
        for pid in $pids; do
            kill "$pid" 2>/dev/null && print_ok "已终止进程 PID: $pid"
        done
        return 0
    fi

    local pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        # 等待优雅退出
        local waited=0
        while kill -0 "$pid" 2>/dev/null && [[ $waited -lt 30 ]]; do
            sleep 1
            ((waited++))
        done
        # 如果还没退出，强制杀死
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid"
            print_warn "进程未响应，已强制终止 (PID: $pid)"
        else
            print_ok "应用已停止 (PID: $pid)"
        fi
    else
        print_ok "进程已不存在 (PID: $pid)"
    fi

    rm -f "$PID_FILE"
}

# ------------------------------ 状态 ----------------------------------------
do_status() {
    print_step "服务状态..."

    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            local port="${SERVER_PORT:-8081}"
            print_ok "运行中 (PID: $pid)"
            echo ""
            # 尝试健康检查
            if command -v curl &>/dev/null; then
                local health_url="http://localhost:${port}/actuator/health"
                local health_resp
                health_resp=$(curl -s -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null || echo "000")
                if [[ "$health_resp" == "200" ]]; then
                    print_ok "健康检查通过 (HTTP $health_resp)"
                else
                    print_warn "健康检查返回 HTTP $health_resp（可能还在启动中）"
                fi
            fi
        else
            print_err "PID 文件存在但进程已死 (PID: $pid)"
            rm -f "$PID_FILE"
        fi
    else
        # 尝试查找进程
        local pids
        pids=$(pgrep -f "group45-backend" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            print_warn "发现运行中的进程但无 PID 文件: $pids"
        else
            print_warn "应用未运行"
        fi
    fi

    # 显示最近日志
    if [[ -f "$APP_LOG" ]]; then
        echo ""
        echo -e "  ${BOLD}最近日志 (最后 10 行):${NC}"
        echo "  ------------------------------------------------------------"
        tail -10 "$APP_LOG" | sed 's/^/  /'
        echo "  ------------------------------------------------------------"
    fi
}

# ------------------------------ 帮助 ----------------------------------------
do_help() {
    print_header
    echo "用法: ./deploy.sh [命令]"
    echo ""
    echo "命令:"
    echo "  infra-up      一键启动 Docker 基础设施 (MySQL/Redis/ES/Kafka/MinIO)"
    echo "  infra-down    停止/销毁 Docker 基础设施"
    echo "  infra-status  查看 Docker 容器运行状态"
    echo "  build         只编译项目"
    echo "  start         编译 + 前台启动（适合调试，Ctrl+C 停止）"
    echo "  start-bg      编译 + 后台启动（适合长期运行）"
    echo "  stop          停止后台运行的应用"
    echo "  status        查看服务运行状态"
    echo "  check         只检测环境（不等启动）"
    echo "  help          显示此帮助"
    echo ""
    echo "环境变量:"
    echo "  SKIP_TESTS=true  编译时跳过测试（默认 true）"
    echo "  EDITOR=vim       编辑 .env 时使用的编辑器"
    echo ""
    echo "前置依赖:"
    echo "  - Docker Desktop / Docker Engine (运行 infra-up 时必需)"
    echo "  - JDK 17+         https://adoptium.net"
    echo "  - Maven 3.9+      https://maven.apache.org"
    echo "  - LiteParse        (可选，pip install 'mineru[core]')"
    echo ""
    echo "示例 (首次部署):"
    echo "  ./deploy.sh infra-up     # 1. 启动 Docker 基础设施"
    echo "  ./deploy.sh start-bg     # 2. 编译 + 后台启动应用"
    echo "  ./deploy.sh status       # 3. 看状态"
    echo "  tail -f logs/app.log     # 4. 实时看日志"
}

# ------------------------------ 交互式引导 ----------------------------------
do_interactive() {
    print_header
    echo -e "  ${YELLOW}此脚本将引导你完成 Group45 Backend 的部署${NC}"
    echo ""

    # Step 0: Docker 基础设施
    echo -e "${BOLD}━━━ Step 0/4: Docker 基础设施 ━━━${NC}"
    if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
        print_ok "Docker 可用"

        # 检查容器是否已在运行
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "prototype"; then
            print_ok "检测到 prototype 相关容器已在运行"
            echo ""
            read -r -p "  是否重新启动基础设施？(y/n) [默认: n]: " restart_infra
            if [[ "$restart_infra" =~ ^[Yy] ]]; then
                do_infra_up
            fi
        else
            echo ""
            print_tip "检测到你还没有启动基础设施（MySQL/Redis/ES/Kafka/MinIO）"
            read -r -p "  是否用 Docker 一键启动？(y/n) [默认: y]: " start_infra
            start_infra="${start_infra:-y}"
            if [[ "$start_infra" =~ ^[Yy] ]]; then
                do_infra_up
            else
                print_warn "跳过基础设施，请确保 MySQL/Redis/ES/Kafka/MinIO 已手动启动"
            fi
        fi
    else
        print_warn "Docker 不可用，跳过基础设施自动部署"
        print_tip "请确保 MySQL/Redis/ES/Kafka/MinIO 已手动启动"
    fi
    echo ""

    # Step 1: 环境检测
    echo -e "${BOLD}━━━ Step 1/4: 环境检测 ━━━${NC}"
    check_java
    check_maven
    check_liteparse
    echo ""

    # Step 2: 配置文件
    echo -e "${BOLD}━━━ Step 2/4: 配置文件 ━━━${NC}"
    check_env_file
    echo ""

    # Step 3: 基础设施检查
    echo -e "${BOLD}━━━ Step 3/4: 基础设施连接 ━━━${NC}"
    check_infrastructure
    echo ""

    # Step 4: 编译与启动
    echo -e "${BOLD}━━━ Step 4/4: 编译与启动 ━━━${NC}"

    if [[ ! -f "$ENV_FILE" ]]; then
        print_err ".env 文件不存在，无法继续"
        exit 1
    fi

    do_build

    echo ""
    echo -e "  请选择启动模式:"
    echo "  1) 前台启动（适合调试，Ctrl+C 停止）"
    echo "  2) 后台启动（适合长期运行）"
    echo "  3) 跳过启动（只编译）"
    echo ""
    read -r -p "  请输入选项 (1/2/3) [默认: 1]: " mode_choice
    mode_choice="${mode_choice:-1}"

    case "$mode_choice" in
        1) do_start "foreground" ;;
        2) do_start "background" ;;
        3) print_ok "编译完成，跳过启动" ;;
        *) print_err "无效选项" ; exit 1 ;;
    esac
}

# ------------------------------ 主入口 --------------------------------------
main() {
    cd "$BACKEND_DIR"

    case "${1:-}" in
        infra-up)
            do_infra_up
            ;;
        infra-down)
            do_infra_down
            ;;
        infra-status)
            do_infra_status
            ;;
        build)
            check_java
            check_maven
            do_build
            ;;
        start)
            check_java
            check_maven
            check_env_file
            do_build
            do_start "foreground"
            ;;
        start-bg)
            check_java
            check_maven
            check_env_file
            do_build
            do_start "background"
            ;;
        stop)
            do_stop
            ;;
        status)
            do_status
            ;;
        check)
            check_java
            check_maven
            check_env_file
            check_infrastructure
            check_liteparse
            print_ok "环境检测完成"
            ;;
        help|--help|-h)
            do_help
            ;;
        "")
            do_interactive
            ;;
        *)
            echo -e "${RED}未知命令: $1${NC}"
            echo "运行 ./deploy.sh help 查看帮助"
            exit 1
            ;;
    esac
}

main "$@"
