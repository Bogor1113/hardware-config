# 大数据集群配置文件归档

> 云策电商数仓项目 · 单节点集群全量配置快照

本仓库归档了一套完整的单节点大数据集群配置文件，涵盖**离线数仓**与**实时数仓**两条链路，
面向教学与实验环境，重点在于**低配硬件下的稳定性调优**。

---

## 一、集群规格

| 项目 | 值 |
|---|---|
| 主机 | 192.168.42.101（Ubuntu 20.04 LTS） |
| 物理内存 | 10 GB（9918 MB 可用） |
| CPU | 4 vCPU |
| 磁盘 | 60 GB（根分区） |
| JDK | Oracle JDK 8（`/opt/jdk`） |
| Hadoop | 3.3.4（`/opt/hadoop3`） |
| Hive | 3.1.3（`/opt/hive3`） |
| Tez | 0.10.2（`/opt/tez-0.10.2`） |
| Spark | 3.0.0（`/opt/spark2`） |

---

## 二、目录结构

```
hardware-config/
├── 01-hadoop/              Hadoop 配置（core/hdfs/yarn/mapred/capacity-scheduler）
├── 02-hive/                Hive 配置（hive-site/tez-site/hive-env/hcatalog）
├── 03-tez/                 Tez 配置（tez-site）
├── 04-spark/               Spark 配置（spark-defaults/spark-env/hive-site）
├── 05-flink/               Flink 配置（flink-conf.yaml）
├── 06-kafka/               Kafka 配置
├── 07-zookeeper/           ZooKeeper 配置
├── 08-flume/               Flume 配置
├── 09-sqoop/               Sqoop 配置
├── 10-datax/               DataX 配置
├── 11-doris/               Doris 配置（FE/BE/HDFS-Broker）
├── 12-dolphinscheduler/    DolphinScheduler 配置（standalone/master/worker/api/alert/tools）
├── 13-mysql/               MySQL 配置
├── 90-system/              ★ 系统级配置（fstab/sysctl/limits/profile/sshd）
├── 91-env/                 环境变量脚本（*-env.sh / flink-conf.yaml）
├── 92-startup-scripts/     ★ 集群启停脚本与运维笔记
└── 93-offline-warehouse-sql/  ★ 离线数仓 SQL 项目（ODS/DWD/DWS/ADS）
```

---

## 三、★ 离线数仓（Offline Warehouse）

**启动脚本**：`92-startup-scripts/offline-warehouse_260822.sh`

组件：`MySQL` → `Hadoop (HDFS/YARN)` → `Hive Metastore` → `HiveServer2` → `DolphinScheduler`

```bash
bash offline-warehouse_260822.sh {start|stop|restart|status}
```

**SQL 项目**：`93-offline-warehouse-sql/`（分层建模）

| 层级 | 文件 | 说明 |
|---|---|---|
| ODS | `ods/*/*.sql` | 8 张源表（订单/明细/支付/用户/商品/品牌/品类/码表） |
| DWD | `dwd/dwd_user_order_clean.sql` | 订单明细清洗（订单×商品粒度，210 万行） |
| DWS | `dws/dws_user_day_snapshot.sql` | 用户日快照 |
| DWS | `dws/dws_user_topic_wide.sql` | **用户主题宽表**（188,566 用户，含 RFM/偏好标签） |
| ADS | `ads/ads_user_daily_report.sql` | 用户日报 |

---

## 四、★ 实时数仓（Realtime Warehouse）

**启动脚本**：`92-startup-scripts/realtime-warehouse_260822.sh`

组件：`ZooKeeper` → `Kafka` → `Flink` → `Doris (FE/BE)` + `Hive Metastore`

```bash
bash realtime-warehouse_260822.sh {start|stop|restart|status}
```

| 组件 | 端口 |
|---|---|
| ZooKeeper | 2181 |
| Kafka | 9092 |
| Hive Metastore | 9083 |
| Doris FE | 9030 |
| Doris BE | 9050 |
| Flink | 8081 |

---

## 五、★ 关键调优：10GB 内存下的稳定性优先

本仓库的配置不是"性能最大化"，而是**"绝 OOM 优先"**——教学场景可以慢，不能崩。

### 5.1 核心原则

> **小内存机器上，容器规格必须跟着资源池缩。容器越小，反而越能并行。**

原配置在 10GB 下的实测风险：

| 指标 | 未适配 | 适配后 |
|---|---|---|
| 内存已用峰值 | 9715 MB（98%） | 7263 ~ 8085 MB |
| **可用内存最低** | **11 MB** ⚠️ | **1517 ~ 2372 MB** |
| **Swap 峰值** | **447 MB** ⚠️ | **4 ~ 19 MB** |
| DWS 宽表耗时 | 73.8 s | **51.5 ~ 54.0 s** |

**降配反而更快的原因**：`hive.tez.container.size` 从 2048MB 降到 1024MB 后，
4096MB 的 YARN 池从"只能放 1 个 task"变成"能放 3 个 task"，DAG 并行度恢复。

### 5.2 关键参数

**YARN**（`01-hadoop/hadoop-etc/yarn-site.xml`）

| 参数 | 值 |
|---|---|
| `yarn.nodemanager.resource.memory-mb` | 4096 |
| `yarn.scheduler.maximum-allocation-mb` | 4096 |
| `yarn.nodemanager.resource.cpu-vcores` | 4 |

**Tez**（`02-hive/conf/tez-site.xml` + `03-tez/conf/tez-site.xml`，两份必须一致）

| 参数 | 值 |
|---|---|
| `tez.task.resource.memory.mb` | 1024 |
| `tez.task.java.opts` | `-Xmx768m -XX:+UseParallelGC -XX:+HeapDumpOnOutOfMemoryError` |
| `tez.runtime.io.sort.mb` | 128 |
| `tez.runtime.shuffle.parallel.copies` | 5 |
| `tez.runtime.io.sort.factor` | 15 |
| `tez.am.resource.memory.mb` | 1024 |

**Hive**（`02-hive/conf/hive-site.xml`）

| 参数 | 值 |
|---|---|
| `hive.tez.container.size` | 1024 |
| `hive.tez.java.opts` | `-Xmx768m -XX:+UseParallelGC -XX:+HeapDumpOnOutOfMemoryError` |
| `hive.auto.convert.join.noconditionaltask.size` | 16777216 |
| `hive.exec.parallel` | false |
| `hive.groupby.skewindata` | false |

**Spark**（`04-spark/conf/spark-defaults.conf`）

| 参数 | 值 |
|---|---|
| `spark.executor.memory` | 1024m |
| `spark.executor.memoryOverhead` | 256m |
| `spark.executor.instances` | 1 |
| `spark.driver.memory` | 1024m |
| `spark.yarn.am.memory` | 512m |
| `spark.sql.shuffle.partitions` | 4 |

### 5.3 系统级加固

| 文件 | 关键改动 |
|---|---|
| `90-system/fstab` | swapfile 缩容至 1GB（原 4GB），保留 OOM 兜底 |
| `90-system/sysctl.d/99-hadoop-tune.conf` | 内核参数调优（swappiness / overcommit） |
| `90-system/limits.conf` | 文件句柄与进程数上限 |

> **重要**：swap 不可完全关闭。1GB 是保险丝——内存打满时靠换页顶住，
> 而不是让 OOM Killer 杀掉 HiveServer2 / NodeManager（进程被杀 = 连接断开 + 任务消失）。

---

## 六、⚠️ 安全说明

**本仓库所有明文凭据已脱敏**，统一替换为 `__REDACTED__`。

- 涉及文件：Hive Metastore 密码、DolphinScheduler 数据库密码与 JWT token、Sqoop 配置等
- 真实值保存在本地 `_secrets/` 目录（**已加入 .gitignore，不会推送**）
- `_local-backups/` 存放历史备份文件（同样不推送）

部署到新环境时，需将 `__REDACTED__` 替换为实际凭据。

---

## 七、已知问题（教学素材）

### 7.1 `dws_user_topic_wide.sql` 的 `or` 恒真 Bug

```sql
sum(if (payment_time is not null
    or payment_time != '', 1, 0)) as pay_order_count  -- 恒为 1，等价于 order_count
```

应改为 `and`。实测 188566 行中 100% 满足 `pay_order_count = order_count`。
**此 Bug 保留未修**，作为课堂分析案例。

### 7.2 明细表粒度陷阱

`dwd.dwd_user_order_clean` 是**订单×商品**粒度（2,105,259 行 / 698,565 订单，
80% 订单占多行，最多 10 行）。直接 `sum(order_total_amount)` 会虚增 3.7 倍
（185.43 亿 vs 真值 50.06 亿），必须先按 `order_id` 去重。

---

## 八、验收数据

DWS 宽表 `dws.dws_user_topic_wide` 基线：

| 指标 | 值 |
|---|---|
| 用户数 | 188,566 |
| 订单数 | 698,565 |
| 订单金额 | 5,006,110,682.06 |
| 支付金额 | 4,507,587,659.41 |

---

*最后更新：2026-10-07*
