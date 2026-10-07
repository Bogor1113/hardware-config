#!/bin/bash

# ============================================
# 实时数仓集群管理脚本
# 适配 Ubuntu 20.04 LTS
# 用法: ./realtime-warehouse.sh {start|stop|status|restart}
# ============================================

# 确保使用 bash 执行
if [ -z "$BASH_VERSION" ]; then
    echo "请使用 bash 执行此脚本: bash $0"
    exit 1
fi

# ============================================
# 颜色定义
# ============================================
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    RED=$(tput setaf 1 2>/dev/null)
    GREEN=$(tput setaf 2 2>/dev/null)
    YELLOW=$(tput setaf 3 2>/dev/null)
    BLUE=$(tput setaf 4 2>/dev/null)
    NC=$(tput sgr0 2>/dev/null)
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# ============================================
# 配置区域（请根据实际路径修改）
# ============================================
HADOOP_HOME=/opt/hadoop3
HIVE_HOME=/opt/hive3
KAFKA_HOME=/opt/kafka
FLINK_HOME=/opt/flink
DORIS_HOME=/opt/doris
ZOOKEEPER_HOME=/opt/zookeeper

# 端口配置
ZOOKEEPER_PORT=2181
HIVE_METASTORE_PORT=9083
KAFKA_PORT=9092
DORIS_FE_PORT=9030
DORIS_BE_PORT=9050
FLINK_PORT=8081

# JDK 环境
export JAVA_HOME=/opt/jdk
export PATH=$JAVA_HOME/bin:$PATH

# 日志目录
LOG_DIR=/opt/bigdata-start-logs
mkdir -p $LOG_DIR 2>/dev/null

# ============================================
# 打印函数（使用 printf 替代 echo -e）
# ============================================
log_info() {
    printf "%b[INFO]%b %s\n" "$GREEN" "$NC" "$1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/cluster.log"
}

log_warn() {
    printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/cluster.log"
}

log_error() {
    printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_DIR/cluster.log"
}

print_line() {
    printf "%s\n" "$1"
}

# ============================================
# 服务管理函数（兼容 systemctl 和 service）
# ============================================
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
    fi
    return 1
}

service_stop() {
    local service=$1
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$service" 2>/dev/null
        return $?
    elif command -v service >/dev/null 2>&1; then
        service "$service" stop 2>/dev/null
        return $?
    fi
    return 1
}

# ============================================
# 工具函数
# ============================================
check_port() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | grep -E ":$port " | grep -q LISTEN && return 0
    fi
    if command -v lsof >/dev/null 2>&1; then
        lsof -i:$port -sTCP:LISTEN 2>/dev/null | grep -q LISTEN && return 0
    fi
    if command -v nc >/dev/null 2>&1; then
        nc -z localhost $port 2>/dev/null && return 0
    fi
    return 1
}

check_process() {
    local pattern=$1
    ps aux 2>/dev/null | grep -v grep | grep -E "$pattern" | awk '{print $2}' | head -1
}

wait_for_port() {
    local port=$1
    local timeout=${2:-30}
    local start=$(date +%s)
    while ! check_port $port; do
        sleep 1
        local now=$(date +%s)
        if [ $((now - start)) -ge $timeout ]; then
            return 1
        fi
    done
    return 0
}

# ============================================
# 1. ZooKeeper
# ============================================
start_zookeeper() {
    log_info "启动 ZooKeeper..."
    $ZOOKEEPER_HOME/bin/zkServer.sh start >> "$LOG_DIR/zookeeper.log" 2>&1
    sleep 2
    if check_port $ZOOKEEPER_PORT; then
        log_info "ZooKeeper 启动成功 (端口: $ZOOKEEPER_PORT)"
        return 0
    else
        log_error "ZooKeeper 启动失败"
        return 1
    fi
}

stop_zookeeper() {
    log_info "停止 ZooKeeper..."
    $ZOOKEEPER_HOME/bin/zkServer.sh stop >> "$LOG_DIR/zookeeper.log" 2>&1
    log_info "ZooKeeper 已停止"
}

status_zookeeper() {
    if check_port $ZOOKEEPER_PORT; then
        local pid=$(check_process "QuorumPeerMain")
        printf "  ZooKeeper: %b运行中%b (PID: %s, 端口: %d)\n" "$GREEN" "$NC" "${pid:-未知}" $ZOOKEEPER_PORT
        return 0
    fi
    printf "  ZooKeeper: %b未运行%b\n" "$RED" "$NC"
    return 1
}

# ============================================
# 2. HDFS
# ============================================
start_hdfs() {
    log_info "启动 HDFS..."
    $HADOOP_HOME/sbin/start-dfs.sh >> "$LOG_DIR/hdfs.log" 2>&1
    sleep 5
    if check_process "NameNode"; then
        log_info "HDFS 启动成功"
        return 0
    else
        log_error "HDFS 启动失败"
        return 1
    fi
}

stop_hdfs() {
    log_info "停止 HDFS..."
    $HADOOP_HOME/sbin/stop-dfs.sh >> "$LOG_DIR/hdfs.log" 2>&1
    log_info "HDFS 已停止"
}

status_hdfs() {
    local nn_pid=$(check_process "NameNode")
    local dn_pid=$(check_process "DataNode")
    if [ -n "$nn_pid" ]; then
        printf "  HDFS NameNode: %b运行中%b (PID: %s)\n" "$GREEN" "$NC" "$nn_pid"
    else
        printf "  HDFS NameNode: %b未运行%b\n" "$RED" "$NC"
    fi
    if [ -n "$dn_pid" ]; then
        printf "  HDFS DataNode: %b运行中%b (PID: %s)\n" "$GREEN" "$NC" "$dn_pid"
    else
        printf "  HDFS DataNode: %b未运行%b\n" "$RED" "$NC"
    fi
}

# ============================================
# 3. MySQL (Hive Metastore 依赖)
# ============================================
start_mysql() {
    log_info "启动 MySQL..."
    if service_is_active "mysql"; then
        log_info "MySQL 已在运行"
        return 0
    fi
    service_start "mysql"
    sleep 3
    if check_port 3306; then
        log_info "MySQL 启动成功 (端口: 3306)"
        return 0
    else
        log_error "MySQL 启动失败"
        return 1
    fi
}

stop_mysql() {
    log_info "停止 MySQL..."
    service_stop "mysql"
    log_info "MySQL 已停止"
}

status_mysql() {
    if check_port 3306; then
        printf "  MySQL: %b运行中%b (端口: 3306)\n" "$GREEN" "$NC"
    else
        printf "  MySQL: %b未运行%b\n" "$RED" "$NC"
    fi
}

# ============================================
# 4. Hive Metastore
# ============================================
start_hive_metastore() {
    log_info "启动 Hive Metastore..."
    
    if check_port $HIVE_METASTORE_PORT; then
        log_info "Hive Metastore 已在运行 (端口: $HIVE_METASTORE_PORT)"
        return 0
    fi
    
    nohup $HIVE_HOME/bin/hive --service metastore > $LOG_DIR/hive-metastore.log 2>&1 &
    local pid=$!
    
    if wait_for_port $HIVE_METASTORE_PORT 30; then
        log_info "Hive Metastore 启动成功 (端口: $HIVE_METASTORE_PORT, PID: $pid)"
        return 0
    else
        log_error "Hive Metastore 启动失败，请查看日志: $LOG_DIR/hive-metastore.log"
        tail -20 $LOG_DIR/hive-metastore.log 2>/dev/null
        return 1
    fi
}

stop_hive_metastore() {
    log_info "停止 Hive Metastore..."
    local pid=$(check_process "Metastore")
    if [ -n "$pid" ]; then
        kill -15 $pid 2>/dev/null
        sleep 2
        log_info "Hive Metastore 已停止 (PID: $pid)"
    else
        log_info "Hive Metastore 未运行"
    fi
}

status_hive_metastore() {
    if check_port $HIVE_METASTORE_PORT; then
        local pid=$(check_process "Metastore")
        printf "  Hive Metastore: %b运行中%b (PID: %s, 端口: %d)\n" "$GREEN" "$NC" "${pid:-未知}" $HIVE_METASTORE_PORT
        return 0
    fi
    printf "  Hive Metastore: %b未运行%b\n" "$RED" "$NC"
    return 1
}

# ============================================
# 5. Kafka
# ============================================
start_kafka() {
    log_info "启动 Kafka..."
    
    if check_port $KAFKA_PORT; then
        log_info "Kafka 已在运行 (端口: $KAFKA_PORT)"
        return 0
    fi
    
    nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > $LOG_DIR/kafka.log 2>&1 &
    local pid=$!
    
    if wait_for_port $KAFKA_PORT 30; then
        log_info "Kafka 启动成功 (端口: $KAFKA_PORT, PID: $pid)"
        return 0
    else
        log_error "Kafka 启动失败，请查看日志: $LOG_DIR/kafka.log"
        return 1
    fi
}

stop_kafka() {
    log_info "停止 Kafka..."
    $KAFKA_HOME/bin/kafka-server-stop.sh 2>/dev/null
    sleep 3
    local pid=$(check_process "kafka\.Kafka")
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null
    fi
    log_info "Kafka 已停止"
}

status_kafka() {
    if check_port $KAFKA_PORT; then
        local pid=$(check_process "kafka\.Kafka")
        printf "  Kafka: %b运行中%b (PID: %s, 端口: %d)\n" "$GREEN" "$NC" "${pid:-未知}" $KAFKA_PORT
        return 0
    fi
    printf "  Kafka: %b未运行%b\n" "$RED" "$NC"
    return 1
}

# ============================================
# 6. Doris FE
# ============================================
start_doris_fe() {
    log_info "启动 Doris FE..."
    
    if check_port $DORIS_FE_PORT; then
        log_info "Doris FE 已在运行 (端口: $DORIS_FE_PORT)"
        return 0
    fi
    
    $DORIS_HOME/fe/bin/start_fe.sh --daemon >> $LOG_DIR/doris-fe.log 2>&1
    
    if wait_for_port $DORIS_FE_PORT 30; then
        log_info "Doris FE 启动成功 (端口: $DORIS_FE_PORT)"
        return 0
    else
        log_error "Doris FE 启动失败"
        return 1
    fi
}

stop_doris_fe() {
    log_info "停止 Doris FE..."
    $DORIS_HOME/fe/bin/stop_fe.sh >> $LOG_DIR/doris-fe.log 2>&1
    log_info "Doris FE 已停止"
}

status_doris_fe() {
    if check_port $DORIS_FE_PORT; then
        local pid=$(check_process "DorisFE")
        printf "  Doris FE: %b运行中%b (PID: %s, 端口: %d)\n" "$GREEN" "$NC" "${pid:-未知}" $DORIS_FE_PORT
        return 0
    fi
    printf "  Doris FE: %b未运行%b\n" "$RED" "$NC"
    return 1
}

# ============================================
# 7. Doris BE
# ============================================
start_doris_be() {
    log_info "启动 Doris BE..."
    
    if check_port $DORIS_BE_PORT; then
        log_info "Doris BE 已在运行 (端口: $DORIS_BE_PORT)"
        return 0
    fi
    
    $DORIS_HOME/be/bin/start_be.sh --daemon >> $LOG_DIR/doris-be.log 2>&1
    
    if wait_for_port $DORIS_BE_PORT 30; then
        log_info "Doris BE 启动成功 (端口: $DORIS_BE_PORT)"
        return 0
    else
        log_error "Doris BE 启动失败"
        return 1
    fi
}

stop_doris_be() {
    log_info "停止 Doris BE..."
    $DORIS_HOME/be/bin/stop_be.sh >> $LOG_DIR/doris-be.log 2>&1
    log_info "Doris BE 已停止"
}

status_doris_be() {
    if check_port $DORIS_BE_PORT; then
        local pid=$(check_process "DorisBE")
        printf "  Doris BE: %b运行中%b (PID: %s, 端口: %d)\n" "$GREEN" "$NC" "${pid:-未知}" $DORIS_BE_PORT
        return 0
    fi
    printf "  Doris BE: %b未运行%b\n" "$RED" "$NC"
    return 1
}

# ============================================
# 8. Flink
# ============================================
start_flink() {
    log_info "启动 Flink..."
    
    if check_port $FLINK_PORT; then
        log_info "Flink 已在运行 (端口: $FLINK_PORT)"
        return 0
    fi
    
    $FLINK_HOME/bin/start-cluster.sh >> $LOG_DIR/flink.log 2>&1
    
    if wait_for_port $FLINK_PORT 30; then
        log_info "Flink 启动成功 (端口: $FLINK_PORT)"
        return 0
    else
        log_error "Flink 启动失败"
        return 1
    fi
}

stop_flink() {
    log_info "停止 Flink..."
    $FLINK_HOME/bin/stop-cluster.sh >> $LOG_DIR/flink.log 2>&1
    log_info "Flink 已停止"
}

status_flink() {
    if check_port $FLINK_PORT; then
        local jm_pid=$(check_process "StandaloneSessionClusterEntrypoint")
        local tm_pid=$(check_process "TaskManagerRunner")
        printf "  Flink JobManager: %b运行中%b (PID: %s, 端口: %d)\n" "$GREEN" "$NC" "${jm_pid:-未知}" $FLINK_PORT
        if [ -n "$tm_pid" ]; then
            printf "  Flink TaskManager: %b运行中%b (PID: %s)\n" "$GREEN" "$NC" "$tm_pid"
        fi
        return 0
    fi
    printf "  Flink: %b未运行%b\n" "$RED" "$NC"
    return 1
}

# ============================================
# 完整启动（按依赖顺序）
# ============================================
full_start() {
    print_line ""
    print_line "============================================"
    print_line "      启动实时数仓集群"
    print_line "============================================"
    print_line ""
    
    local fail_count=0
    
    start_zookeeper || ((fail_count++))
    sleep 3
    
    start_hdfs || ((fail_count++))
    sleep 5
    
    start_mysql || ((fail_count++))
    sleep 3
    
    start_hive_metastore || ((fail_count++))
    sleep 3
    
    start_kafka || ((fail_count++))
    sleep 3
    
    start_doris_fe || ((fail_count++))
    sleep 5
    
    start_doris_be || ((fail_count++))
    sleep 3
    
    start_flink || ((fail_count++))
    
    print_line ""
    print_line "============================================"
    if [ $fail_count -eq 0 ]; then
        log_info "所有组件启动成功！"
    else
        log_warn "$fail_count 个组件启动失败，请检查日志"
    fi
    print_line "============================================"
    print_line ""
    print_line "Web UI 访问地址："
    print_line "  - NameNode:    http://hadoop101:9870"
    print_line "  - Flink:       http://hadoop101:8081"
    print_line "  - Doris FE:    http://hadoop101:8030"
    print_line ""
}

# ============================================
# 完整停止（逆序）
# ============================================
full_stop() {
    print_line ""
    print_line "============================================"
    print_line "      停止实时数仓集群"
    print_line "============================================"
    print_line ""
    
    stop_flink
    stop_doris_be
    stop_doris_fe
    stop_kafka
    stop_hive_metastore
    stop_mysql
    stop_hdfs
    stop_zookeeper
    
    print_line ""
    log_info "实时数仓集群已停止"
    print_line "============================================"
    print_line ""
}

# ============================================
# 完整状态检查
# ============================================
full_status() {
    print_line ""
    print_line "============================================"
    print_line "      实时数仓集群状态"
    print_line "============================================"
    print_line ""
    
    print_line "[1. ZooKeeper]"
    status_zookeeper
    print_line ""
    
    print_line "[2. HDFS]"
    status_hdfs
    print_line ""
    
    print_line "[3. MySQL]"
    status_mysql
    print_line ""
    
    print_line "[4. Hive Metastore]"
    status_hive_metastore
    print_line ""
    
    print_line "[5. Kafka]"
    status_kafka
    print_line ""
    
    print_line "[6. Doris]"
    status_doris_fe
    status_doris_be
    print_line ""
    
    print_line "[7. Flink]"
    status_flink
    print_line ""
    
    print_line "============================================"
    print_line ""
}

# ============================================
# 重启
# ============================================
full_restart() {
    full_stop
    sleep 5
    full_start
}

# ============================================
# 帮助信息
# ============================================
show_help() {
    print_line "用法: $0 {start|stop|restart|status}"
    print_line ""
    print_line "  start   - 启动所有组件（按依赖顺序）"
    print_line "  stop    - 停止所有组件（逆序）"
    print_line "  restart - 重启所有组件"
    print_line "  status  - 查看所有组件状态"
    print_line ""
    print_line "配置文件路径："
    print_line "  - Hadoop:  $HADOOP_HOME"
    print_line "  - Hive:    $HIVE_HOME"
    print_line "  - Kafka:   $KAFKA_HOME"
    print_line "  - Flink:   $FLINK_HOME"
    print_line "  - Doris:   $DORIS_HOME"
    print_line "  - ZK:      $ZOOKEEPER_HOME"
    print_line ""
}

# ============================================
# 主入口
# ============================================
main() {
    if [ $# -ne 1 ]; then
        log_error "缺少参数"
        print_line ""
        show_help
        exit 1
    fi
    
    case "$1" in
        start)   full_start ;;
        stop)    full_stop ;;
        status)  full_status ;;
        restart) full_restart ;;
        help|--help|-h) show_help ;;
        *)
            log_error "未知参数: $1"
            print_line ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"