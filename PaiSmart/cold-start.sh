#!/usr/bin/env bash
# ============================================================
# PaiSmart 冷启动脚本
# 一键启动所有基础设施 + 后端 + 前端
# 用法: ./cold-start.sh [start|stop|status|restart]
# ============================================================
set -u

# ---------- 路径配置 ----------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${PROJECT_DIR}/.runtime"
SERVICES_DIR="${RUNTIME_DIR}/services"
LOGS_DIR="${RUNTIME_DIR}/logs"
PID_DIR="${RUNTIME_DIR}/pids"

# 服务二进制
MINIO_BIN="${SERVICES_DIR}/minio"
MINIO_DATA="${SERVICES_DIR}/minio-data"
KAFKA_DIR="${SERVICES_DIR}/kafka"
KAFKA_CONFIG="${KAFKA_DIR}/config/kraft/server.properties"
ES_DIR="${SERVICES_DIR}/elasticsearch"
FRONTEND_DIR="${PROJECT_DIR}/frontend"

# 工具链
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
MAVEN="${HOME}/.local/maven/bin/mvn"
NODE_BIN="${HOME}/.local/node-v22.16.0-linux-x64/bin"

# 端口
BACKEND_PORT="${BACKEND_PORT:-8082}"
FRONTEND_PORT="${FRONTEND_PORT:-9527}"
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
KAFKA_PORT=9092
ES_PORT=9200
MYSQL_PORT=3306
REDIS_PORT=6379

# 数据库
MYSQL_USER="root"
MYSQL_PASS="PaiSmart2025"
MYSQL_DB="PaiSmart"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------- 确保运行时目录 ----------
mkdir -p "${LOGS_DIR}" "${PID_DIR}"

# ---------- 工具函数 ----------
log()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
err()  { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
step() { printf "\n${BLUE}==> %s${NC}\n" "$1"; }

port_open() {
    nc -z 127.0.0.1 "$1" 2>/dev/null
}

wait_for_port() {
    local port="$1" label="$2" max="${3:-30}"
    local i=0
    while [ $i -lt $max ]; do
        if port_open "$port"; then
            log "${label} 就绪 (端口 ${port})"
            return 0
        fi
        [ $((i % 5)) -eq 0 ] && log "等待 ${label}... (${i}s)"
        sleep 1
        i=$((i + 1))
    done
    err "${label} 启动超时 (端口 ${port})"
    return 1
}

http_ok() {
    curl -s --fail --max-time 3 "$1" > /dev/null 2>&1
}

# ---------- 检查前置条件 ----------
check_prereqs() {
    step "检查前置条件"

    local missing=0

    if [ ! -x "${JAVA_HOME}/bin/java" ]; then
        err "Java 未找到: ${JAVA_HOME}/bin/java"
        missing=1
    else
        log "Java: $(${JAVA_HOME}/bin/java -version 2>&1 | head -1)"
    fi

    if [ ! -x "${MAVEN}" ]; then
        err "Maven 未找到: ${MAVEN}"
        missing=1
    else
        log "Maven: $(${MAVEN} -version 2>&1 | head -1)"
    fi

    if [ ! -x "${NODE_BIN}/node" ]; then
        err "Node 未找到: ${NODE_BIN}/node"
        missing=1
    else
        log "Node: $(${NODE_BIN}/node -v)"
    fi

    if [ ! -x "${NODE_BIN}/pnpm" ]; then
        err "pnpm 未找到: ${NODE_BIN}/pnpm"
        missing=1
    else
        log "pnpm: $(${NODE_BIN}/pnpm -v)"
    fi

    return $missing
}

# ---------- MySQL ----------
start_mysql() {
    step "MySQL"

    if port_open ${MYSQL_PORT}; then
        log "MySQL 已在运行 (端口 ${MYSQL_PORT})"
    else
        log "启动 MySQL..."
        sudo systemctl start mysql 2>/dev/null || sudo service mysql start 2>/dev/null || {
            err "无法启动 MySQL"
            return 1
        }
        wait_for_port ${MYSQL_PORT} "MySQL" 15 || return 1
    fi

    # 确保数据库存在
    log "检查数据库 ${MYSQL_DB}..."
    mysql -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e "
        CREATE DATABASE IF NOT EXISTS ${MYSQL_DB}
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    " 2>/dev/null
    log "数据库 ${MYSQL_DB} 就绪"
}

# ---------- Redis ----------
start_redis() {
    step "Redis"

    if port_open ${REDIS_PORT} && redis-cli ping > /dev/null 2>&1; then
        log "Redis 已在运行 (端口 ${REDIS_PORT})"
    else
        log "启动 Redis..."
        sudo systemctl start redis 2>/dev/null || sudo service redis-server start 2>/dev/null || {
            err "无法启动 Redis"
            return 1
        }
        wait_for_port ${REDIS_PORT} "Redis" 15 || return 1
    fi
}

# ---------- MinIO ----------
start_minio() {
    step "MinIO"

    if port_open ${MINIO_API_PORT}; then
        log "MinIO 已在运行 (端口 ${MINIO_API_PORT})"
        return 0
    fi

    if [ ! -x "${MINIO_BIN}" ]; then
        err "MinIO 二进制文件未找到: ${MINIO_BIN}"
        return 1
    fi

    if [ ! -d "${MINIO_DATA}" ]; then
        mkdir -p "${MINIO_DATA}"
    fi

    log "启动 MinIO..."
    nohup "${MINIO_BIN}" server "${MINIO_DATA}" \
        --console-address ":${MINIO_CONSOLE_PORT}" \
        --address ":${MINIO_API_PORT}" \
        > "${LOGS_DIR}/minio.log" 2>&1 &

    echo $! > "${PID_DIR}/minio.pid"
    wait_for_port ${MINIO_API_PORT} "MinIO" 20 || return 1
}

# ---------- Kafka (KRaft 模式) ----------
start_kafka() {
    step "Kafka"

    if port_open ${KAFKA_PORT}; then
        log "Kafka 已在运行 (端口 ${KAFKA_PORT})"
        return 0
    fi

    if [ ! -f "${KAFKA_DIR}/bin/kafka-server-start.sh" ]; then
        err "Kafka 未找到: ${KAFKA_DIR}"
        return 1
    fi

    if [ ! -f "${KAFKA_CONFIG}" ]; then
        err "Kafka KRaft 配置未找到: ${KAFKA_CONFIG}"
        return 1
    fi

    # 格式化 KRaft storage（幂等操作）
    local kraft_dir="/tmp/kraft-combined-logs"
    if [ ! -f "${kraft_dir}/meta.properties" ]; then
        log "格式化 KRaft storage..."
        local cluster_id
        cluster_id="$("${KAFKA_DIR}/bin/kafka-storage.sh" random-uuid 2>/dev/null)"
        "${KAFKA_DIR}/bin/kafka-storage.sh" format \
            -t "${cluster_id}" \
            -c "${KAFKA_CONFIG}" \
            --ignore-formatted > /dev/null 2>&1
    fi

    log "启动 Kafka (KRaft)..."
    export JAVA_HOME
    nohup "${KAFKA_DIR}/bin/kafka-server-start.sh" "${KAFKA_CONFIG}" \
        > "${LOGS_DIR}/kafka.log" 2>&1 &

    echo $! > "${PID_DIR}/kafka.pid"
    wait_for_port ${KAFKA_PORT} "Kafka" 45 || return 1
}

# ---------- Elasticsearch ----------
start_elasticsearch() {
    step "Elasticsearch"

    if port_open ${ES_PORT}; then
        log "Elasticsearch 已在运行 (端口 ${ES_PORT})"
        return 0
    fi

    if [ ! -f "${ES_DIR}/bin/elasticsearch" ]; then
        err "Elasticsearch 未找到: ${ES_DIR}"
        return 1
    fi

    log "启动 Elasticsearch..."
    export JAVA_HOME
    ES_JAVA_OPTS="-Xms500M -Xmx500M" nohup "${ES_DIR}/bin/elasticsearch" \
        > "${LOGS_DIR}/elasticsearch.log" 2>&1 &

    echo $! > "${PID_DIR}/elasticsearch.pid"
    wait_for_port ${ES_PORT} "Elasticsearch" 45 || return 1
}

# ---------- 启动所有基础设施 ----------
start_infra() {
    step "========== 启动基础设施 =========="
    start_mysql    || return 1
    start_redis    || return 1
    start_minio    || return 1
    start_kafka    || return 1
    start_elasticsearch || return 1
    step "========== 基础设施全部就绪 =========="
}

# ---------- 启动基础设施 + 后端（自动判断状态，缺啥启啥）----------
start_infra_and_backend() {
    check_prereqs || return 1

    # 先看一遍当前状态
    echo ""
    echo "============================================"
    echo "  启动前检查..."
    echo "============================================"
    local infra_ok=0 backend_ok=0
    if port_open ${MYSQL_PORT} && port_open ${REDIS_PORT} && \
       port_open ${MINIO_API_PORT} && port_open ${KAFKA_PORT} && \
       port_open ${ES_PORT}; then
        infra_ok=1
    fi
    if port_open ${BACKEND_PORT}; then
        backend_ok=1
    fi
    echo "  基础设施: $([ $infra_ok -eq 1 ] && echo '✅ 全部在线' || echo '⚠️  部分缺失')"
    echo "  后端:      $([ $backend_ok -eq 1 ] && echo '✅ 已在运行' || echo '⚠️  未启动')"
    echo "============================================"
    echo ""

    # 基础设施
    if [ $infra_ok -eq 1 ]; then
        log "基础设施已全部在线，跳过"
    else
        start_infra || return 1
    fi

    # 后端
    if [ $backend_ok -eq 1 ]; then
        log "后端已在运行 (端口 ${BACKEND_PORT})"
    else
        start_backend || return 1
    fi

    echo ""
    echo "============================================"
    echo -e "  ${GREEN}基础设施 + 后端 就绪！${NC}"
    echo ""
    echo -e "  后端 API: ${BLUE}http://localhost:${BACKEND_PORT}/api/v1${NC}"
    echo "============================================"
    echo ""
}

# ---------- 启动后端 ----------
start_backend() {
    step "========== 启动后端 (Spring Boot) =========="

    if port_open ${BACKEND_PORT}; then
        warn "端口 ${BACKEND_PORT} 已被占用，后端可能已在运行"
        return 0
    fi

    cd "${PROJECT_DIR}"

    # 编译（如果 target 不存在则完整编译，否则增量编译）
    if [ ! -f "target/classes/com/yizhaoqi/smartpai/SmartPaiApplication.class" ]; then
        log "首次编译（可能需要几分钟）..."
        "${MAVEN}" compile -q
    fi

    log "启动 Spring Boot (端口 ${BACKEND_PORT})..."
    export PATH="${JAVA_HOME}/bin:${MAVEN%/*}:${PATH}"
    export MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-minioadmin}"
    export MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-minioadmin}"
    SERVER_PORT=${BACKEND_PORT} "${MAVEN}" spring-boot:run \
        -Dspring-boot.run.arguments="--server.port=${BACKEND_PORT}" \
        > "${LOGS_DIR}/backend.log" 2>&1 &

    echo $! > "${PID_DIR}/backend.pid"

    # Spring Boot 启动较慢，等待时间放长
    wait_for_port ${BACKEND_PORT} "后端" 90 || {
        err "后端启动失败，查看日志: tail -100 ${LOGS_DIR}/backend.log"
        return 1
    }

    log "后端就绪: http://localhost:${BACKEND_PORT}/api/v1"
}

# ---------- 启动前端 ----------
start_frontend() {
    step "========== 启动前端 (Vue 3 + Vite) =========="

    if port_open ${FRONTEND_PORT}; then
        warn "端口 ${FRONTEND_PORT} 已被占用，前端可能已在运行"
        return 0
    fi

    cd "${FRONTEND_DIR}"

    # 安装依赖
    if [ ! -d "node_modules" ]; then
        log "安装前端依赖..."
        "${NODE_BIN}/pnpm" install --silent
    fi

    # 同步后端端口到前端配置
    local env_file="${FRONTEND_DIR}/.env.test"
    if [ -f "${env_file}" ]; then
        sed -i "s|localhost:[0-9]\+/api|localhost:${BACKEND_PORT}/api|g" "${env_file}"
    fi

    log "启动前端 (端口 ${FRONTEND_PORT})..."
    "${NODE_BIN}/pnpm" run dev \
        > "${LOGS_DIR}/frontend.log" 2>&1 &

    echo $! > "${PID_DIR}/frontend.pid"

    wait_for_port ${FRONTEND_PORT} "前端" 30 || {
        err "前端启动超时，查看日志: tail -50 ${LOGS_DIR}/frontend.log"
        return 1
    }

    log "前端就绪: http://localhost:${FRONTEND_PORT}/"
}

# ---------- 启动全部 ----------
start_all() {
    check_prereqs   || return 1
    start_infra     || return 1
    start_backend   || return 1
    start_frontend  || return 1

    echo ""
    echo "============================================"
    echo -e "  ${GREEN}PaiSmart 冷启动完成！${NC}"
    echo ""
    echo -e "  前端:     ${BLUE}http://localhost:${FRONTEND_PORT}/${NC}"
    echo -e "  后端 API: ${BLUE}http://localhost:${BACKEND_PORT}/api/v1${NC}"
    echo -e "  MinIO:    ${BLUE}http://localhost:${MINIO_CONSOLE_PORT}/${NC}"
    echo ""
    echo -e "  管理员:   admin / PaiSmart2025!"
    echo "============================================"
    echo ""
}

# ---------- 停止 ----------
stop_service_by_pid() {
    local name="$1"
    local pid_file="${PID_DIR}/${name}.pid"
    if [ -f "${pid_file}" ]; then
        local pid
        pid=$(cat "${pid_file}" 2>/dev/null | tr -d '[:space:]')
        if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
            log "停止 ${name} (PID ${pid})..."
            kill "${pid}" 2>/dev/null || true
            sleep 1
            kill -9 "${pid}" 2>/dev/null || true
        fi
        rm -f "${pid_file}"
    fi
}

stop_all() {
    step "========== 停止 PaiSmart =========="

    stop_service_by_pid "frontend"
    stop_service_by_pid "backend"

    # 基础设施：只停止我们从 .runtime 启动的（MinIO, Kafka, ES）
    # MySQL 和 Redis 是系统服务，通常保留运行
    for svc in minio kafka elasticsearch; do
        stop_service_by_pid "${svc}"
    done

    # 确保端口释放
    for port in ${BACKEND_PORT} ${FRONTEND_PORT} ${MINIO_API_PORT} ${KAFKA_PORT} ${ES_PORT}; do
        if port_open ${port}; then
            warn "端口 ${port} 仍被占用，尝试强制释放..."
            fuser -k ${port}/tcp 2>/dev/null || true
        fi
    done

    log "所有服务已停止"
}

# ---------- 状态 ----------
status_all() {
    echo "============================================"
    echo "  PaiSmart 服务状态"
    echo "============================================"
    echo ""

    check_port() {
        local label="$1" port="$2"
        if port_open "${port}"; then
            printf "  ${GREEN}%-20s${NC} 端口 %s\n" "${label}" "${port}"
        else
            printf "  ${RED}%-20s${NC} 端口 %s (未运行)\n" "${label}" "${port}"
        fi
    }

    check_port "MySQL"          ${MYSQL_PORT}
    check_port "Redis"          ${REDIS_PORT}
    check_port "MinIO API"      ${MINIO_API_PORT}
    check_port "Kafka"          ${KAFKA_PORT}
    check_port "Elasticsearch"  ${ES_PORT}
    check_port "后端 (Spring)"   ${BACKEND_PORT}
    check_port "前端 (Vite)"     ${FRONTEND_PORT}

    echo ""
    echo -e "MinIO Console: ${BLUE}http://localhost:${MINIO_CONSOLE_PORT}/${NC}"
    echo -e "前端:          ${BLUE}http://localhost:${FRONTEND_PORT}/${NC}"
    echo -e "后端 API:      ${BLUE}http://localhost:${BACKEND_PORT}/api/v1${NC}"
    echo "============================================"
}

# ---------- 日志 ----------
show_logs() {
    local svc="${1:-backend}"
    local log_file="${LOGS_DIR}/${svc}.log"
    if [ -f "${log_file}" ]; then
        tail -f "${log_file}"
    else
        err "日志文件不存在: ${log_file}"
        echo "可用: $(ls ${LOGS_DIR}/ 2>/dev/null | grep '\.log$')"
    fi
}

# ---------- 主入口 ----------
show_help() {
    cat << 'EOF'
用法: ./cold-start.sh <命令> [选项]

命令:
  start          冷启动全部服务（基础设施 → 后端 → 前端）
  stop           停止全部服务
  restart        重启全部服务
  status         查看所有服务状态
  logs [服务名]  查看服务日志（默认: backend）
  infra          仅启动/重启基础设施
  backend        启动基础设施 + 后端（自动判断状态，缺啥启啥）

示例:
  ./cold-start.sh start              # 一键冷启动
  ./cold-start.sh stop               # 停止全部
  ./cold-start.sh status             # 查看状态
  ./cold-start.sh logs frontend      # 查看前端日志
  ./cold-start.sh infra              # 仅启动 MySQL/Redis/MinIO/Kafka/ES
  ./cold-start.sh backend            # 启动基础设施 + 后端（跳过前端）

环境变量:
  BACKEND_PORT     后端端口 (默认: 8082)
  FRONTEND_PORT    前端端口 (默认: 9527)
EOF
}

case "${1:-}" in
    start)
        start_all
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        sleep 2
        start_all
        ;;
    status)
        status_all
        ;;
    logs)
        show_logs "${2:-backend}"
        ;;
    infra)
        check_prereqs || exit 1
        start_infra
        ;;
    backend)
        start_infra_and_backend
        ;;
    -h|--help|help|"")
        show_help
        ;;
    *)
        err "未知命令: ${1:-}"
        show_help
        exit 1
        ;;
esac
