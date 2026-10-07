#!/bin/bash

# ======================================================
# 离线数仓集群管理脚本（单节点独立版）
# 组件：MySQL, Hadoop, Hive Metastore, HiveServer2, DolphinScheduler
# 适配 Ubuntu 20.04 LTS
# 用法：./offline-warehouse.sh {start|stop|restart|status}
# ======================================================

# 确保脚本使用 bash 执行
if [ -z "$BASH_VERSION" ]; then
    echo "请使用 bash 执行此脚本: bash $0"
    exit 1
fi

# ======================================================
# 颜色定义
# ======================================================
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1 2>/dev/null)
    GREEN=$(tput setaf 2 2>/dev/null)
    YELLOW=$(tput setaf 3 2>/dev/null)
    NC=$(tput sgr0 2>/dev/null)
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi

# ======================================================
# 组件安装路径（请根据实际路径修改）
# ======================================================
# --- load system environment so jps/JAVA_HOME are available ---
[ -f /etc/profile ] && . /etc/profile >/dev/null 2>&1
export JAVA_HOME="${JAVA_HOME:-/opt/jdk}"

HADOOP_HOME=/opt/hadoop3
HIVE_HOME=/opt/hive3
MYSQL_SERVICE_NAME=mysql
DOLPHIN_HOME=/opt/dolphinscheduler

# 日志文件
LOG_FILE="/var/log/datawarehouse_cluster.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

# ======================================================
# 函数：打印信息
# ======================================================
print_info() {
    printf "%b[信息]%b %s\n" "$GREEN" "$NC" "$1"
    echo "[信息] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_warn() {
    printf "%b[警告]%b %s\n" "$YELLOW" "$NC" "$1"
    echo "[警告] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_error() {
    printf "%b[错误]%b %s\n" "$RED" "$NC" "$1" >&2
    echo "[错误] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_line() {
    printf "%s\n" "$1"
    echo "$1" >> "$LOG_FILE"
}

# ======================================================
# 函数：检查端口是否被占用
# ======================================================
check_port() {
    local port=$1
    # 优先使用 ss (Ubuntu 默认)
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | grep -E ":$port " | grep -q LISTEN && return 0
    fi
    # 备选 lsof
    if command -v lsof >/dev/null 2>&1; then
        lsof -i:$port -sTCP:LISTEN 2>/dev/null | grep -q LISTEN && return 0
    fi
    # 备选 netstat
    if command -v netstat >/dev/null 2>&1; then
        netstat -tuln 2>/dev/null | grep -E ":$port " | grep -q LISTEN && return 0
    fi
    return 1
}

# ======================================================
# 函数：检查 systemd 服务状态
# ======================================================
service_is_active() {
    local service=$1
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active --quiet "$service" 2>/dev/null && return 0
    elif command -v service >/dev/null 2>&1; then
        service "$service" status 2>/dev/null | grep -qi "running" && return 0
    fi
    return 1
}

service_start() {
    local service=$1
    if command -v systemctl >/dev/null 2>&1; then
        systemctl start "$service" 2>/dev/null
        return $?
    elif command -v service >/dev/null 2>&1; then
        service "$service" start 2>/dev/null
        return $?
    else
        return 1
    fi
}

service_stop() {
    local service=$1
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$service" 2>/dev/null
        return $?
    elif command -v service >/dev/null 2>&1; then
        service "$service" stop 2>/dev/null
        return $?
    else
        return 1
    fi
}

# ======================================================
# 函数：检查 Hadoop 相关进程
# ======================================================
check_jps() {
    local jps_bin
    jps_bin=$(command -v jps 2>/dev/null)
    if [ -z "$jps_bin" ]; then
        jps_bin="${JAVA_HOME:-/opt/jdk}/bin/jps"
    fi
    "$jps_bin" 2>/dev/null | grep -v Jps
}

# ======================================================
# 函数：启动 Hadoop
# ======================================================
start_hadoop() {
    print_info "正在启动 Hadoop 集群..."
    
    if [ ! -d "$HADOOP_HOME" ]; then
        print_error "Hadoop 安装目录不存在: $HADOOP_HOME"
        return 1
    fi
    
    if [ ! -x "$HADOOP_HOME/sbin/start-all.sh" ]; then
        print_error "Hadoop 启动脚本不存在或无执行权限: $HADOOP_HOME/sbin/start-all.sh"
        return 1
    fi
    
    # 检查是否已启动
    local jps_out=$(check_jps)
    if echo "$jps_out" | grep -qE 'NameNode|DataNode'; then
        print_warn "Hadoop 似乎已经在运行"
        return 0
    fi
    
    "$HADOOP_HOME/sbin/start-all.sh" >> "$LOG_FILE" 2>&1
    local ret=$?

    # JVMs take a while to spawn; poll up to 60s
    local waited=0
    jps_out=""
    while [ $waited -lt 60 ]; do
        sleep 5
        waited=$((waited + 5))
        jps_out=$(check_jps)
        if echo "$jps_out" | grep -qE 'NameNode' && \
           echo "$jps_out" | grep -qE 'DataNode' && \
           echo "$jps_out" | grep -qE 'ResourceManager'; then
            break
        fi
        printf "."
    done
    printf "\n"
    if echo "$jps_out" | grep -qE 'NameNode|DataNode|ResourceManager|NodeManager'; then
        print_info "Hadoop 启动成功"
        return 0
    else
        print_error "Hadoop 启动失败，返回码: $ret"
        print_error "请检查日志: $HADOOP_HOME/logs/"
        return 1
    fi
}

# ======================================================
# 函数：停止 Hadoop
# ======================================================
stop_hadoop() {
    print_info "正在停止 Hadoop 集群..."

    if [ ! -x "$HADOOP_HOME/sbin/stop-all.sh" ]; then
        print_error "Hadoop 停止脚本不存在或无执行权限"
        return 1
    fi

    "$HADOOP_HOME/sbin/stop-all.sh" >> "$LOG_FILE" 2>&1
    sleep 5

    local jps_out=$(check_jps)
    if echo "$jps_out" | grep -qE 'NameNode|DataNode|SecondaryNameNode|ResourceManager|NodeManager'; then
        print_warn "发现残留 Hadoop 进程，强制 kill -9 ..."
        echo "$jps_out" | grep -E 'NameNode|DataNode|SecondaryNameNode|ResourceManager|NodeManager' | awk '{print $1}' | xargs -r kill -9 2>/dev/null
        sleep 2
    fi

    jps_out=$(check_jps)
    if echo "$jps_out" | grep -qE 'NameNode|DataNode|SecondaryNameNode|ResourceManager|NodeManager'; then
        print_error "Hadoop 进程未能完全停止，请手动检查"
        return 1
    fi

    print_info "Hadoop 已停止"
    return 0
}

# ======================================================
# 函数：查看 Hadoop 状态
# ======================================================
status_hadoop() {
    printf "Hadoop: "
    local jps_out=$(check_jps)
    if echo "$jps_out" | grep -qE 'NameNode|DataNode|ResourceManager|NodeManager'; then
        printf "%b运行中%b\n" "$GREEN" "$NC"
        echo "$jps_out" | grep -E 'NameNode|DataNode|ResourceManager|NodeManager' | while read line; do
            printf "  %s\n" "$line"
        done
    else
        printf "%b已停止%b\n" "$RED" "$NC"
    fi
}

# ======================================================
# 函数：启动 Hive Metastore
# ======================================================
start_hive_metastore() {
    print_info "正在启动 Hive Metastore 服务..."
    
    if [ ! -d "$HIVE_HOME" ]; then
        print_error "Hive 安装目录不存在: $HIVE_HOME"
        return 1
    fi
    
    if [ ! -x "$HIVE_HOME/bin/hive" ]; then
        print_error "Hive 执行文件不存在或无执行权限: $HIVE_HOME/bin/hive"
        return 1
    fi
    
    if check_port 9083; then
        print_warn "Hive Metastore 已经在运行中 (端口 9083)"
        return 0
    fi
    
    # 启动 metastore
    nohup "$HIVE_HOME/bin/hive" --service metastore >> /tmp/hive_metastore.log 2>&1 &
    local pid=$!
    
    print_info "等待 Hive Metastore 启动..."
    local max_wait=30
    local waited=0
    while [ $waited -lt $max_wait ]; do
        sleep 2
        waited=$((waited + 2))
        if check_port 9083; then
            print_info "Hive Metastore 启动成功 (端口 9083, PID: $pid)"
            return 0
        fi
        printf "."
    done
    printf "\n"
    
    print_error "Hive Metastore 启动超时"
    print_error "请查看日志: /tmp/hive_metastore.log"
    tail -20 /tmp/hive_metastore.log 2>/dev/null
    return 1
}

# ======================================================
# 函数：启动 HiveServer2
# ======================================================
start_hiveserver2() {
    print_info "正在启动 HiveServer2 服务..."

    if [ ! -d "$HIVE_HOME" ]; then
        print_error "Hive 安装目录不存在: $HIVE_HOME"
        return 1
    fi

    if check_port 10000; then
        print_warn "HiveServer2 已经在运行中 (端口 10000)"
        return 0
    fi

    nohup "$HIVE_HOME/bin/hive" --service hiveserver2 >> /tmp/hiveserver2.log 2>&1 &
    local pid=$!

    print_info "HiveServer2 正在后台启动 (PID: $pid)，日志: /tmp/hiveserver2.log"
    print_info "等待 HiveServer2 端口就绪（最长 120 秒）..."
    local max_wait=120
    local waited=0
    while [ $waited -lt $max_wait ]; do
        sleep 2
        waited=$((waited + 2))
        if check_port 10000; then
            print_info "HiveServer2 启动成功 (端口 10000, PID: $pid)"
            return 0
        fi
        printf "."
    done
    printf "\n"

    print_error "HiveServer2 启动超时"
    print_error "请查看日志: /tmp/hiveserver2.log"
    tail -20 /tmp/hiveserver2.log 2>/dev/null
    return 1
}

# ======================================================
# 函数：停止 Hive Metastore
# ======================================================
stop_hive_metastore() {
    print_info "正在停止 Hive Metastore..."

    local pids=$(ps -ef 2>/dev/null | grep -v grep | grep "HiveMetaStore" | awk '{print $2}')
    if [ -z "$pids" ]; then
        print_warn "Hive Metastore 未运行"
        return 0
    fi

    echo "$pids" | xargs kill -15 2>/dev/null
    sleep 3
    pids=$(ps -ef 2>/dev/null | grep -v grep | grep "HiveMetaStore" | awk '{print $2}')
    if [ -n "$pids" ]; then
        print_warn "Metastore 存在残留进程，强制 kill -9: $(echo $pids | tr '\n' ' ')"
        echo "$pids" | xargs kill -9 2>/dev/null
        sleep 1
    fi
    print_info "Hive Metastore 已停止"
}

# ======================================================
# 函数：停止 HiveServer2
# ======================================================
stop_hiveserver2() {
    print_info "正在停止 HiveServer2..."

    local pids=$(ps -ef 2>/dev/null | grep -v grep | grep "HiveServer2" | awk '{print $2}')
    if [ -z "$pids" ]; then
        print_warn "HiveServer2 未运行"
        return 0
    fi

    echo "$pids" | xargs kill -15 2>/dev/null
    sleep 3
    pids=$(ps -ef 2>/dev/null | grep -v grep | grep "HiveServer2" | awk '{print $2}')
    if [ -n "$pids" ]; then
        print_warn "HiveServer2 存在残留进程，强制 kill -9: $(echo $pids | tr '\n' ' ')"
        echo "$pids" | xargs kill -9 2>/dev/null
        sleep 1
    fi
    print_info "HiveServer2 已停止"
}

# ======================================================
# 函数：查看 Hive 状态
# ======================================================
status_hive() {
    printf "Hive Metastore: "
    if check_port 9083; then
        printf "%b运行中%b\n" "$GREEN" "$NC"
        local pid=$(ps -ef 2>/dev/null | grep -v grep | grep "HiveMetaStore" | awk '{print $2}' | head -1)
        printf "  PID: %s, 端口: 9083\n" "${pid:-未知}"
    else
        printf "%b已停止%b\n" "$RED" "$NC"
    fi
    
    printf "HiveServer2: "
    if check_port 10000; then
        printf "%b运行中%b\n" "$GREEN" "$NC"
        local pid=$(ps -ef 2>/dev/null | grep -v grep | grep "HiveServer2" | awk '{print $2}' | head -1)
        printf "  PID: %s, 端口: 10000\n" "${pid:-未知}"
    else
        printf "%b未运行%b\n" "$YELLOW" "$NC"
    fi
}

# ======================================================
# 函数：启动 MySQL
# ======================================================
start_mysql() {
    print_info "正在启动 MySQL..."
    
    # 先检查服务是否已运行
    if service_is_active "$MYSQL_SERVICE_NAME"; then
        print_warn "MySQL 已经在运行中"
        return 0
    fi
    
    # 尝试启动
    if service_start "$MYSQL_SERVICE_NAME"; then
        sleep 2
        if service_is_active "$MYSQL_SERVICE_NAME"; then
            print_info "MySQL 启动成功"
            return 0
        fi
    fi
    
    print_error "MySQL 启动失败"
    # 尝试获取错误信息
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status "$MYSQL_SERVICE_NAME" --no-pager 2>&1 | head -10
    fi
    return 1
}

# ======================================================
# 函数：停止 MySQL
# ======================================================
stop_mysql() {
    print_info "正在停止 MySQL..."
    service_stop "$MYSQL_SERVICE_NAME"
    sleep 2
    print_info "MySQL 已停止"
}

# ======================================================
# 函数：查看 MySQL 状态
# ======================================================
status_mysql() {
    printf "MySQL: "
    if service_is_active "$MYSQL_SERVICE_NAME"; then
        printf "%b运行中%b\n" "$GREEN" "$NC"
    else
        printf "%b已停止%b\n" "$RED" "$NC"
    fi
}

# ======================================================
# 函数：启动 DolphinScheduler
# ======================================================
start_dolphin() {
    print_info "正在启动 DolphinScheduler (standalone 模式)..."
    
    if [ ! -d "$DOLPHIN_HOME" ]; then
        print_error "DolphinScheduler 安装目录不存在: $DOLPHIN_HOME"
        return 1
    fi
    
    if [ ! -x "$DOLPHIN_HOME/bin/dolphinscheduler-daemon.sh" ]; then
        print_error "DolphinScheduler 启动脚本不存在或无执行权限"
        return 1
    fi
    
    if check_port 12345; then
        print_warn "DolphinScheduler 已经在运行中 (端口 12345)"
        return 0
    fi
    
    cd "$DOLPHIN_HOME" || return 1
    nohup "$DOLPHIN_HOME/bin/dolphinscheduler-daemon.sh" start standalone-server >> /tmp/dolphinscheduler-standalone.log 2>&1 &
    
    print_info "等待 DolphinScheduler 启动..."
    local max_wait=30
    local waited=0
    while [ $waited -lt $max_wait ]; do
        sleep 2
        waited=$((waited + 2))
        if check_port 12345; then
            print_info "DolphinScheduler 启动成功"
            print_info "  访问地址: http://localhost:12345/dolphinscheduler"
            print_info "  默认用户名: admin"
            print_info "  默认密码: dolphinscheduler123"
            return 0
        fi
        printf "."
    done
    printf "\n"
    
    print_error "DolphinScheduler 启动超时"
    print_error "请查看日志: /tmp/dolphinscheduler-standalone.log"
    tail -30 /tmp/dolphinscheduler-standalone.log 2>/dev/null
    return 1
}

# ======================================================
# 函数：停止 DolphinScheduler
# ======================================================
stop_dolphin() {
    print_info "正在停止 DolphinScheduler..."
    
    if [ -x "$DOLPHIN_HOME/bin/dolphinscheduler-daemon.sh" ]; then
        cd "$DOLPHIN_HOME" 2>/dev/null
        "$DOLPHIN_HOME/bin/dolphinscheduler-daemon.sh" stop standalone-server >> "$LOG_FILE" 2>&1
    fi
    
    sleep 5
    
    local pids=$(ps -ef 2>/dev/null | grep -v grep | grep -E "dolphinscheduler|standalone-server" | awk '{print $2}')
    if [ -n "$pids" ]; then
        print_warn "发现残留进程，强制停止..."
        echo "$pids" | xargs kill -9 2>/dev/null
        sleep 2
    fi
    
    print_info "DolphinScheduler 已停止"
}

# ======================================================
# 函数：查看 DolphinScheduler 状态
# ======================================================
status_dolphin() {
    printf "DolphinScheduler: "
    if check_port 12345; then
        printf "%b运行中%b\n" "$GREEN" "$NC"
        local pid=$(ps -ef 2>/dev/null | grep -v grep | grep -E "dolphinscheduler|standalone-server" | awk '{print $2}' | head -1)
        printf "  PID: %s\n" "${pid:-未知}"
        printf "  端口: 12345\n"
        printf "  访问地址: http://localhost:12345/dolphinscheduler\n"
    else
        printf "%b已停止%b\n" "$RED" "$NC"
    fi
}

# ======================================================
# 函数：启动所有组件
# ======================================================
start_all() {
    print_line ""
    print_info "=========================================="
    print_info "正在启动离线数仓集群"
    print_info "=========================================="
    
    start_mysql || exit 1
    print_line ""
    
    start_hadoop || exit 1
    print_line ""
    
    start_hive_metastore || exit 1
    print_line ""
    
    start_hiveserver2 || exit 1
    print_line ""
    
    start_dolphin || exit 1
    print_line ""
    
    print_info "=========================================="
    print_info "所有组件启动完成"
    print_info "=========================================="
    status_all
}

# ======================================================
# 函数：停止所有组件
# ======================================================
stop_all() {
    print_line ""
    print_info "=========================================="
    print_info "正在停止离线数仓集群"
    print_info "=========================================="
    
    stop_dolphin
    print_line ""
    
    stop_hiveserver2
    print_line ""
    
    stop_hive_metastore
    print_line ""
    
    stop_hadoop
    print_line ""
    
    stop_mysql
    print_line ""
    
    print_info "=========================================="
    print_info "所有组件已停止"
    print_info "=========================================="
}

# ======================================================
# 函数：重启所有组件
# ======================================================
restart_all() {
    print_info "=========================================="
    print_info "正在重启离线数仓集群"
    print_info "=========================================="
    stop_all
    sleep 3
    start_all
}

# ======================================================
# 函数：查看所有组件状态
# ======================================================
status_all() {
    print_line ""
    print_line "=========================================="
    print_line "离线数仓集群状态"
    print_line "=========================================="
    status_mysql
    print_line ""
    status_hadoop
    print_line ""
    status_hive
    print_line ""
    status_dolphin
    print_line "=========================================="
    print_line ""
}

# ======================================================
# 主函数
# ======================================================
main() {
    if [ $# -ne 1 ]; then
        printf "使用方法: %s {start|stop|restart|status}\n" "$0"
        printf "\n"
        printf "  start   - 启动所有组件\n"
        printf "  stop    - 停止所有组件\n"
        printf "  restart - 重启所有组件\n"
        printf "  status  - 查看所有组件状态\n"
        printf "\n"
        printf "组件端口信息:\n"
        printf "  - MySQL: 3306\n"
        printf "  - Hive Metastore: 9083\n"
        printf "  - HiveServer2: 10000\n"
        printf "  - DolphinScheduler: 12345\n"
        exit 1
    fi
    
    case "$1" in
        start)   start_all ;;
        stop)    stop_all ;;
        restart) restart_all ;;
        status)  status_all ;;
        *)
            printf "%b[错误]%b 未知命令: %s\n" "$RED" "$NC" "$1"
            printf "使用方法: %s {start|stop|restart|status}\n" "$0"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"