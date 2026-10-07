#!/bin/bash
# ============================================================
# Tez 启动慢 / 并行等待 / 容器不复用 —— 一键诊断
# 用法: bash tez_startup_diag.sh
# 产出: 根因定位（AM坑位 / session复用 / 超时秒表）
# ============================================================
export JAVA_HOME=/opt/jdk
export HADOOP_HOME=/opt/hadoop3
export HIVE_HOME=/opt/hive3
export PATH=$HADOOP_HOME/bin:$HIVE_HOME/bin:$PATH

LOGS=/opt/hadoop3/logs
RM=$(ls -t $LOGS/hadoop-*-resourcemanager-*.log 2>/dev/null | head -1)
NM=$(ls -t $LOGS/hadoop-*-nodemanager-*.log 2>/dev/null | head -1)

P() {
  v=$(grep -A1 "<name>$2</name>" "$1" 2>/dev/null | grep -oP '(?<=<value>).*?(?=</value>)' | head -1)
  echo "    $2 = ${v:-<缺失>}"
}

echo "============================================================"
echo " 1. 物理资源 & 常驻开销"
echo "============================================================"
free -m | head -2
echo "CPU 核数: $(nproc)"
uptime

echo
echo "============================================================"
echo " 2. YARN 资源池（AM 坑位的分母）"
echo "============================================================"
P /opt/hadoop3/etc/hadoop/yarn-site.xml yarn.nodemanager.resource.memory-mb
P /opt/hadoop3/etc/hadoop/yarn-site.xml yarn.nodemanager.resource.cpu-vcores
P /opt/hadoop3/etc/hadoop/yarn-site.xml yarn.scheduler.minimum-allocation-mb
P /opt/hadoop3/etc/hadoop/capacity-scheduler.xml yarn.scheduler.capacity.maximum-am-resource-percent
NM_MEM=$(grep -A1 "<name>yarn.nodemanager.resource.memory-mb</name>" /opt/hadoop3/etc/hadoop/yarn-site.xml | grep -oP '(?<=<value>).*?(?=</value>)')
AM_PCT=$(grep -A1 "<name>yarn.scheduler.capacity.maximum-am-resource-percent</name>" /opt/hadoop3/etc/hadoop/capacity-scheduler.xml | grep -oP '(?<=<value>).*?(?=</value>)')
AM_MEM=$(grep -A1 "<name>tez.am.resource.memory.mb</name>" /opt/hive3/conf/tez-site.xml | grep -oP '(?<=<value>).*?(?=</value>)')
echo "    --------------------------------------------------"
echo "    NM 池 ${NM_MEM}MB x ${AM_PCT} = $(( NM_MEM * ${AM_PCT/0./} / 10 ))MB 额度"
echo "    ÷ AM ${AM_MEM}MB  ==>  AM 坑位 = $(( (NM_MEM * ${AM_PCT/0./} / 10) / AM_MEM )) 个"
echo "    (坑位数 = 能同时运行的独立查询数上限)"

echo
echo "============================================================"
echo " 3. Tez 会话超时（'等 2 分钟' 的秒表来源）"
echo "============================================================"
for f in /opt/hive3/conf/tez-site.xml /opt/tez-0.10.2/conf/tez-site.xml; do
  echo "  --- $f"
  P $f tez.session.client.timeout.secs
  P $f tez.session.am.dag.submit.timeout.secs
  P $f tez.am.container.reuse.enabled
done

echo
echo "============================================================"
echo " 4. 会话复用是否真的生效（关键判据）"
echo "============================================================"
CREATED=$(grep -ac "Tez system stage directory" $NM 2>/dev/null)
REUSED=$(grep -aci "reusing" $NM 2>/dev/null)
echo "    session 创建次数 : ${CREATED:-0}"
echo "    复用成功次数     : ${REUSED:-0}"
if [ "${REUSED:-0}" = "0" ]; then
  echo "    >>> [警告] 复用从未成功过 —— 每个查询都在新建 session/AM"
fi

echo
echo "============================================================"
echo " 5. 当前运行中的应用 & 排队情况"
echo "============================================================"
yarn application -list -appStates RUNNING,ACCEPTED 2>/dev/null | head -12
echo "    --- 队列计数（active=已占坑, pending=排队）---"
grep -a "LeafQueue: Application added" $RM 2>/dev/null | tail -3 | sed 's/.*Application/    Application/'

echo
echo "============================================================"
echo " 6. 最近 AM 排队时长（提交 -> RUNNING）"
echo "============================================================"
grep -aE "State change from (NEW to NEW_SAVING|ACCEPTED to RUNNING)" $RM 2>/dev/null | tail -20 | \
  sed 's/INFO.*RMAppImpl: //'

echo
echo "============================================================"
echo " 7. 内存安全（OOM 检查）"
echo "============================================================"
echo "    NM 日志 Exit 137 次数 : $(grep -c 'Exit code: 137' $NM 2>/dev/null)"
echo "    kern.log OOM 次数     : $(grep -c 'Out of memory: Killed' /var/log/kern.log 2>/dev/null)"

echo
echo "============================================================"
echo " 诊断完成"
echo "============================================================"
echo "判读指南:"
echo "  · 坑位=2 且并行查询数>2        -> 排队的物理原因"
echo "  · 复用次数=0                   -> hive CLI 胖客户端天然不复用"
echo "  · 提交->RUNNING 耗时接近超时值  -> 就是那 2 分钟"
echo "  · 想让并行不吃亏: 改用 beeline（共享同一 session/AM）"
