#!/bin/bash

# 设置密码变量（避免每次输入）
DORIS_PWD="__REDACTED__"

echo "=== 1. 检查进程 ==="
jps | grep -E "DorisFE|DorisBE" || echo "缺少 Doris 进程"

echo -e "\n=== 2. 检查端口 ==="
for port in 8030 9030 9050; do
    netstat -tulnp 2>/dev/null | grep -q ":$port " && echo "端口 $port 监听正常" || echo "端口 $port 未监听"
done

echo -e "\n=== 3. 检查集群状态 ==="
mysql -h 192.168.42.101 -P 9030 -u root -p${DORIS_PWD} -e "SHOW PROC '/backends'\G" 2>/dev/null | grep -E "Host|Alive"

echo -e "\n=== 4. 检查系统资源 ==="
free -h | grep Swap
ulimit -n

echo -e "\n=== 5. 检查最近错误 ==="
tail -5 /opt/doris/fe/log/fe.log 2>/dev/null | grep -i error
tail -5 /opt/doris/be/log/be.log 2>/dev/null | grep -i error
