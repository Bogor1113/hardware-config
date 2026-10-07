export HADOOP_HOME=/opt/hadoop3
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_OPTS="$HADOOP_OPTS -Dhive.log.level=ERROR -Dorg.slf4j.simpleLogger.defaultLogLevel=error"
export TEZ_HOME=/opt/tez-0.10.2
export TEZ_CONF_DIR=$TEZ_HOME/conf
# 只收集 tez 自身 jar（tez-*.jar），排除 tez 自带的 hadoop-* 避免与集群 hadoop 3.3.6 冲突
export TEZ_JARS=$(ls $TEZ_HOME/tez-*.jar | tr '\n' ':' | sed 's/:$//')
export HIVE_AUX_JARS_PATH=$TEZ_JARS
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -Dlog4j.configuration=file:/opt/hive3/conf/client-log4j.properties"

# ============================================================
# [tuned 2026-10-07] 堆口径拆分（v3 - 最终版）
#
# 关键坑（实测踩到）：
#   bin/hive 第 26 行先 source hive-config.sh → 里面写死
#       export HADOOP_HEAPSIZE=${HADOOP_HEAPSIZE:-256}
#   bin/hive 第 100 行才 source 本文件。
#   而 Hadoop 的 hadoop-config.sh 会把 HADOOP_HEAPSIZE 变成 -Xmx 追加到
#   HADOOP_CLIENT_OPTS 的**末尾**。JVM 只认最后一个 -Xmx，所以
#   HADOOP_CLIENT_OPTS 里的 -Xmx 会压过 HIVESERVER2_HADOOP_OPTS。
#   → 因此绝对不能在 HADOOP_CLIENT_OPTS 里放 -Xmx！
#
# 正确分工（三个角色互不干扰）：
#   HS2        → HIVESERVER2_HADOOP_OPTS   1536m
#   Metastore  → HIVE_METASTORE_HADOOP_OPTS 1024m
#   CLI/beeline→ HADOOP_HEAPSIZE             512m（只在纯客户端进程生效）
# ============================================================
export HADOOP_HEAPSIZE=512

export HIVESERVER2_HADOOP_OPTS="-Xmx1536m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+HeapDumpOnOutOfMemoryError"
export HIVE_METASTORE_HADOOP_OPTS="-Xmx1024m -XX:+UseG1GC -XX:+HeapDumpOnOutOfMemoryError"
