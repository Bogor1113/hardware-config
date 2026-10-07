#!/usr/bin/env bash
# [tuned 2026-10-07]
# 原配置把 spark 当 standalone 集群跑（MASTER_HOST/WORKER_MEMORY），
# 但集群实际用 Spark on YARN，两者资源账本冲突。
# 现只保留 YARN 模式必需项。

export JAVA_HOME=/opt/jdk
export HADOOP_CONF_DIR=/opt/hadoop3/etc/hadoop
export SPARK_CONF_DIR=/opt/spark2/conf

# YARN 模式：driver/executor 的内存由 spark-defaults.conf 统一管理
# 这里只给 spark-submit 自身（launcher）的 JVM 一个合理上限
export SPARK_SUBMIT_OPTS="-Xmx512m"
