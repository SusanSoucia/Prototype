#!/usr/bin/env bash
# ==============================================================================
# Prototype 后端一键启停脚本
# 用法: ./cold-start.sh {start|stop|status|logs}
#
# start  - 安装 Docker（如缺失）→ 启动基础设施 → 编译启动后端 → 健康检查
#         本地已有的服务不会重复在容器中启动
# stop   - 停后端 → 停 Docker 容器（仅停脚本自己启动的）→ 释放端口
# status - 查看所有服务运行状态
# logs   - 查看后端运行日志
# ==============================================================================

set -euo pipefail

# ---- 路径 & 端口配置 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
RUNTIME_DIR="$PROJECT_ROOT/.runtime"
LOG_DIR="$RUNTIME_DIR/logs"
PID_DIR="$RUNTIME_DIR/pids"
BACKEND_LOG="$LOG_DIR/backend.log"
BACKEND_PID="$PID_DIR/backend.pid"
BACKEND_PORT="${BACKEND_PORT:-8081}"
COMPOSE_FILE="$(cd "$PROJECT_ROOT/.." && pwd)/docs/docker-compose.yaml"
# 记录本脚本启动了哪些 Docker 服务（用于 stop 时精确停止）
STARTED_SERVICES_FILE="$RUNTIME_DIR/.started_docker_services"

# ---- 基础设施服务定义 ----
# 格式: "docker服务名|端口|显示名|容器名"
INFRA_SERVICES=(
    "mysql|3306|MySQL|prototype-mysql"
    "redis|6379|Redis|prototype-redis"
    "kafka|9092|Kafka|prototype-kafka"
    "elasticsearch|9200|Elasticsearch|prototype-es"
    "minio|9000|MinIO|prototype-minio"
)

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }
log_local() { echo -e "${CYAN}[LOCAL]${NC} $*"; }

# ---- 中断清理 ----
# 确保 Ctrl+C 或 kill 脚本时不留孤儿进程/容器
cleanup_on_interrupt() {
    echo ""
    log_warn "脚本被中断，正在清理资源..."
    # 函数幂等：无运行中服务时为 no-op
    stop_backend 2>/dev/null || true
    stop_infra 2>/dev/null || true
    log_info "清理完成"
    exit 130
}
trap cleanup_on_interrupt INT TERM

# ==============================================================================
# 工具函数
# ==============================================================================

port_open() {
    local host="$1" port="$2"
    (echo >"/dev/tcp/$host/$port") 2>/dev/null
}

wait_for_port() {
    local host="$1" port="$2" max_wait="$3" label="$4"
    local elapsed=0
    log_info "等待 $label ($host:$port) 就绪..."
    while ! port_open "$host" "$port"; do
        if [ "$elapsed" -ge "$max_wait" ]; then
            log_error "$label 等待超时 (${max_wait}s)"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [ $((elapsed % 10)) -eq 0 ]; then
            echo -n "."
        fi
    done
    echo ""
    log_info "$label 已就绪 (${elapsed}s)"
}

# 获取服务定义的各个字段
svc_docker_name() { echo "${INFRA_SERVICES[$1]}" | cut -d'|' -f1; }
svc_port()         { echo "${INFRA_SERVICES[$1]}" | cut -d'|' -f2; }
svc_label()        { echo "${INFRA_SERVICES[$1]}" | cut -d'|' -f3; }
svc_container()    { echo "${INFRA_SERVICES[$1]}" | cut -d'|' -f4; }

# 检查某服务是否本地已可用（端口开放即视为可用）
is_service_local() {
    local port="$1"
    port_open 127.0.0.1 "$port"
}

# 扫描所有基础设施服务，返回本地已可用的服务索引列表（空格分隔）
scan_local_services() {
    local local_idxs=()
    for i in "${!INFRA_SERVICES[@]}"; do
        if is_service_local "$(svc_port "$i")"; then
            local_idxs+=("$i")
        fi
    done
    echo "${local_idxs[*]:-}"
}

# 返回需要 Docker 启动的服务索引列表
scan_missing_services() {
    local missing=()
    for i in "${!INFRA_SERVICES[@]}"; do
        if ! is_service_local "$(svc_port "$i")"; then
            missing+=("$i")
        fi
    done
    echo "${missing[*]:-}"
}

# ==============================================================================
# 前提条件检查
# ==============================================================================

check_prereqs() {
    log_step "检查前提条件..."

    # Java
    if ! command -v java &>/dev/null; then
        log_error "未找到 Java，请安装 JDK 17+"
        exit 1
    fi
    log_info "Java: $(java -version 2>&1 | head -1)"

    # Maven (优先找 mvnw wrapper，其次找全局 mvn)
    if [ -f "$PROJECT_ROOT/mvnw" ] && [ -x "$PROJECT_ROOT/mvnw" ]; then
        MVN_CMD="$PROJECT_ROOT/mvnw"
        log_info "Maven: 使用项目自带的 mvnw wrapper"
    elif [ -f "$PROJECT_ROOT/mvnw" ]; then
        log_warn "mvnw 存在但不可执行，尝试 chmod +x..."
        chmod +x "$PROJECT_ROOT/mvnw"
        MVN_CMD="$PROJECT_ROOT/mvnw"
        log_info "Maven: 使用项目自带的 mvnw wrapper"
    elif command -v mvn &>/dev/null; then
        MVN_CMD="mvn"
        log_info "Maven: $(mvn -version 2>&1 | head -1)"
    else
        log_error "未找到 Maven，请安装 Maven 3.9+ 或确保项目有 mvnw"
        exit 1
    fi

    # Docker — 只有存在缺失服务时才需要 Docker
    local missing
    missing=$(scan_missing_services)
    if [ -n "$missing" ]; then
        if ! command -v docker &>/dev/null; then
            log_warn "未找到 Docker，正在自动安装 docker.io..."
            install_docker
        fi
        log_info "Docker: $(docker --version)"

        # 确认 Docker 守护进程在运行（docker → sudo → sg）
        if ! docker ps &>/dev/null 2>&1 && ! sudo docker ps &>/dev/null 2>&1 && ! sg docker -c "docker ps" &>/dev/null 2>&1; then
            log_error "Docker 守护进程未运行，请先启动 Docker 服务"
            exit 1
        fi

        if ! docker compose version &>/dev/null; then
            log_error "docker compose 不可用，请手动安装 docker-compose-plugin"
            exit 1
        fi
        log_info "Docker Compose: $(docker compose version)"
    else
        log_info "所有基础设施服务本地已可用，无需 Docker"
    fi

    # fuser 用于精确定位端口占用进程（start/stop 核心依赖）
    if ! command -v fuser &>/dev/null; then
        log_error "未找到 fuser 命令，请安装 psmisc 包"
        exit 1
    fi

    log_info "前提条件检查通过"
}

install_docker() {
    log_step "安装 Docker Engine..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io docker-compose-v2
    sudo usermod -aG docker "$USER"

    # 配置 Docker 镜像加速 + 禁用 IPv6（防止国内网络环境下 Docker Hub 超时）
    local daemon_cfg="/etc/docker/daemon.json"
    if [ ! -f "$daemon_cfg" ]; then
        log_info "配置 Docker 镜像加速..."
        sudo mkdir -p /etc/docker
        sudo tee "$daemon_cfg" > /dev/null <<'DOCKERCFG'
{
    "registry-mirrors": [
        "https://docker.1ms.run"
    ],
    "dns": ["8.8.8.8", "114.114.114.114"],
    "ipv6": false
}
DOCKERCFG
        sudo systemctl restart docker
        log_info "Docker 镜像加速已配置"
    fi

    log_info "Docker 安装完成"
    log_warn "已将当前用户加入 docker 组。如果 docker 命令仍然报权限错误，"
    log_warn "请运行: newgrp docker  或重新登录终端"
}

docker_cmd() {
    # 统一 docker 命令入口，自动处理权限（docker → sudo → sg docker）
    if docker ps &>/dev/null 2>&1; then
        docker "$@"
    elif sudo docker ps &>/dev/null 2>&1; then
        sudo docker "$@"
    elif sg docker -c "docker ps" &>/dev/null 2>&1; then
        # sg 需要将参数拼接为单个命令字符串
        local cmd="docker"
        local a
        for a in "$@"; do
            cmd="$cmd $(printf '%q' "$a")"
        done
        sg docker -c "$cmd"
    else
        log_error "无法执行 docker 命令，请检查 Docker 是否已启动"
        exit 1
    fi
}

docker_compose() {
    if docker ps &>/dev/null 2>&1; then
        docker compose -f "$COMPOSE_FILE" "$@"
    elif sudo docker ps &>/dev/null 2>&1; then
        sudo docker compose -f "$COMPOSE_FILE" "$@"
    elif sg docker -c "docker ps" &>/dev/null 2>&1; then
        local cmd="docker compose -f $(printf '%q' "$COMPOSE_FILE")"
        local a
        for a in "$@"; do
            cmd="$cmd $(printf '%q' "$a")"
        done
        sg docker -c "$cmd"
    else
        log_error "无法执行 docker compose，请检查 Docker 是否已启动"
        exit 1
    fi
}

# ==============================================================================
# 基础设施
# ==============================================================================

start_infra() {
    log_step "检测基础设施服务状态..."

    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "找不到 docker-compose.yaml: $COMPOSE_FILE"
        exit 1
    fi

    # 扫描本地服务
    local local_idxs missing_idxs
    local_idxs=($(scan_local_services))
    missing_idxs=($(scan_missing_services))

    # 报告本地已可用的服务
    if [ ${#local_idxs[@]} -gt 0 ]; then
        echo ""
        log_info "以下服务本地已可用，跳过容器启动:"
        for idx in "${local_idxs[@]}"; do
            log_local "  ✓ $(svc_label "$idx") (port $(svc_port "$idx"))"
        done
    fi

    # 如果全部可用
    if [ ${#missing_idxs[@]} -eq 0 ]; then
        echo ""
        log_info "所有基础设施服务均已就绪，无需启动任何容器"
        return 0
    fi

    # 有缺失服务，启动对应 Docker 容器
    echo ""
    log_step "以下服务需要启动容器:"
    local svc_list=()
    for idx in "${missing_idxs[@]}"; do
        log_warn "  → $(svc_label "$idx") (port $(svc_port "$idx"))"
        svc_list+=("$(svc_docker_name "$idx")")
    done

    # 如果需要启动 minio，也要带上 minio-init
    local has_minio=false
    for idx in "${missing_idxs[@]}"; do
        if [ "$(svc_docker_name "$idx")" = "minio" ]; then
            has_minio=true
            break
        fi
    done

    echo ""
    log_info "启动容器: ${svc_list[*]}"
    docker_compose up -d "${svc_list[@]}"

    # 如果启动了 minio，在 minio 健康后运行 minio-init
    if $has_minio; then
        wait_for_port 127.0.0.1 9000 30 "MinIO (新启动)"
        log_info "运行 MinIO 初始化..."
        docker_compose up -d minio-init 2>/dev/null || true
    fi

    # 等待新启动的服务就绪
    for idx in "${missing_idxs[@]}"; do
        local port label
        port=$(svc_port "$idx")
        label=$(svc_label "$idx")
        case "$label" in
            MySQL)         wait_for_port 127.0.0.1 "$port" 60 "$label" ;;
            Redis)         wait_for_port 127.0.0.1 "$port" 30 "$label" ;;
            Kafka)         wait_for_port 127.0.0.1 "$port" 60 "$label" ;;
            Elasticsearch) wait_for_port 127.0.0.1 "$port" 90 "$label" ;;
            MinIO)         wait_for_port 127.0.0.1 "$port" 30 "$label" ;;
        esac
    done

    # 如果是 ES，安装 IK 分词器
    for idx in "${missing_idxs[@]}"; do
        if [ "$(svc_docker_name "$idx")" = "elasticsearch" ]; then
            install_es_ik_plugin
        fi
    done

    # 记录本次启动了哪些服务（用于 stop 时精确停止）
    mkdir -p "$RUNTIME_DIR"
    printf '%s\n' "${svc_list[@]}" > "$STARTED_SERVICES_FILE"

    echo ""
    log_info "基础设施全部就绪"
}

install_es_ik_plugin() {
    local container="prototype-es"
    log_info "检查 ES IK 分词器..."

    if ! docker_cmd exec "$container" /usr/share/elasticsearch/bin/elasticsearch-plugin list 2>/dev/null | grep -q "analysis-ik"; then
        log_info "安装 IK 分词器..."
        docker_cmd exec "$container" /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch analysis-ik
        log_info "重启 ES 使 IK 插件生效..."
        docker_cmd restart "$container"
        # 等 ES 重新就绪
        wait_for_port 127.0.0.1 9200 60 "Elasticsearch (重启后)"
    else
        log_info "IK 分词器已安装"
    fi
}

stop_infra() {
    log_step "停止基础设施容器..."

    if [ -f "$STARTED_SERVICES_FILE" ] && [ -s "$STARTED_SERVICES_FILE" ]; then
        local svc_list
        mapfile -t svc_list < "$STARTED_SERVICES_FILE"
        log_info "仅停止本脚本启动的容器: ${svc_list[*]}"
        docker_compose stop "${svc_list[@]}" 2>/dev/null || true
        rm -f "$STARTED_SERVICES_FILE"
    else
        log_warn "未找到启动记录，将停止所有基础设施容器..."
        docker_compose stop 2>/dev/null || true
    fi

    log_info "容器已停止。如需清除所有数据请运行: docker compose -f $COMPOSE_FILE down -v"
}

# ==============================================================================
# 后端
# ==============================================================================

start_backend() {
    log_step "启动 Spring Boot 后端..."

    mkdir -p "$LOG_DIR" "$PID_DIR"
    cd "$PROJECT_ROOT"

    # 如果 class 文件不存在则先编译
    if [ ! -f "target/classes/com/group45/backend/Group45BackendApplication.class" ]; then
        log_info "首次启动，正在编译项目..."
        $MVN_CMD compile -q
    fi

    # 后台启动（mvn 会 fork 出 JVM 子进程，稍后用 fuser 定位实际 PID）
    nohup $MVN_CMD spring-boot:run \
        -Dspring-boot.run.arguments="--server.port=$BACKEND_PORT" \
        > "$BACKEND_LOG" 2>&1 &
    local mvn_pid=$!
    echo "$mvn_pid" > "$BACKEND_PID"
    log_info "Maven 启动进程 (PID: $mvn_pid)，等待后端就绪..."

    wait_for_port 127.0.0.1 "$BACKEND_PORT" 120 "Spring Boot"

    # 获取实际监听端口的 JVM 进程 PID（而非 mvn 父进程），
    # 确保 stop 时能准确终止 Spring Boot 进程
    local actual_pid
    actual_pid=$(fuser "${BACKEND_PORT}/tcp" 2>/dev/null | tr -d ' ' | grep -oE '[0-9]+' | head -1)
    if [ -n "$actual_pid" ]; then
        echo "$actual_pid" > "$BACKEND_PID"
        log_info "后端进程已启动 (实际 PID: $actual_pid)"
    else
        log_warn "无法确定后端进程 PID，保留 mvn PID: $mvn_pid"
    fi

    log_info "后端启动成功"
}

stop_backend() {
    log_step "停止后端..."

    # 优先通过端口定位实际进程（消除 PID 文件竞态和 mvn-vs-JVM 误判）
    if port_open 127.0.0.1 "$BACKEND_PORT"; then
        local actual_pid
        actual_pid=$(fuser "${BACKEND_PORT}/tcp" 2>/dev/null | tr -d ' ' | grep -oE '[0-9]+' | head -1)
        if [ -n "$actual_pid" ]; then
            log_info "终止后端进程 (PID: $actual_pid)..."
            kill "$actual_pid" 2>/dev/null || true
            # 等待优雅关闭（Spring Boot 最长等待 15s）
            local wait_count=0
            while kill -0 "$actual_pid" 2>/dev/null && [ $wait_count -lt 15 ]; do
                sleep 1
                wait_count=$((wait_count + 1))
            done
            # 如果还没死，强制 kill
            if kill -0 "$actual_pid" 2>/dev/null; then
                log_warn "后端未响应，强制终止..."
                kill -9 "$actual_pid" 2>/dev/null || true
                sleep 1
            fi
        fi
        # 二次确认端口已释放
        if port_open 127.0.0.1 "$BACKEND_PORT"; then
            log_warn "端口仍被占用，强制释放..."
            fuser -k "${BACKEND_PORT}/tcp" 2>/dev/null || true
        fi
    else
        # 端口未占用，但 PID 文件可能存在（进程已异常退出）
        if [ -f "$BACKEND_PID" ]; then
            log_info "后端未在运行，清理过期 PID 文件"
        fi
    fi

    rm -f "$BACKEND_PID"
    log_info "后端已停止"
}

# ==============================================================================
# 状态检查
# ==============================================================================

show_status() {
    echo ""
    echo "========================= 服务状态 ========================="

    # 后端
    if port_open 127.0.0.1 "$BACKEND_PORT"; then
        echo -e "  后端 (port $BACKEND_PORT):    ${GREEN}运行中${NC}"
    else
        echo -e "  后端 (port $BACKEND_PORT):    ${RED}已停止${NC}"
    fi

    echo "  ---"

    # 基础设施服务
    for i in "${!INFRA_SERVICES[@]}"; do
        local port label
        port=$(svc_port "$i")
        label=$(svc_label "$i")

        if is_service_local "$port"; then
            # 判断是本地服务还是 Docker 容器
            local container
            container=$(svc_container "$i")
            if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container"; then
                echo -e "  $label (port $port):  ${GREEN}运行中${NC} (Docker)"
            else
                echo -e "  $label (port $port):  ${GREEN}运行中${NC} ${CYAN}(本地)${NC}"
            fi
        else
            echo -e "  $label (port $port):  ${RED}已停止${NC}"
        fi
    done

    echo "==========================================================="
    echo ""
}

# ==============================================================================
# 日志
# ==============================================================================

show_logs() {
    if [ -f "$BACKEND_LOG" ]; then
        tail -f "$BACKEND_LOG"
    else
        log_error "日志文件不存在: $BACKEND_LOG"
        log_info "请先启动后端: $0 start"
    fi
}

# ==============================================================================
# 主入口
# ==============================================================================

print_usage() {
    echo "用法: $0 {start|stop|status|logs}"
    echo ""
    echo "  start   - 检查环境 → 启动基础设施（跳过本地已有的服务）→ 启动后端"
    echo "  stop    - 停止后端 → 停止本脚本启动的容器"
    echo "  status  - 查看所有服务状态（标注本地/容器）"
    echo "  logs    - 查看后端运行日志"
}

main() {
    local cmd="${1:-}"

    case "$cmd" in
        start)
            check_prereqs
            start_infra
            start_backend
            show_status
            echo ""
            log_info "=============================================="
            log_info "  后端 API:    http://localhost:$BACKEND_PORT"
            log_info "  健康检查:    http://localhost:$BACKEND_PORT/api/health"
            log_info "  MinIO 控制台: http://localhost:9001"
            log_info "  默认管理员:   admin / Prototype2025!"
            log_info "=============================================="
            ;;
        stop)
            stop_backend
            stop_infra
            show_status
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
}

main "$@"
