# Hive 环境问题修复记录

> 环境：hadoop101 (192.168.42.101)　Hadoop 3.1.1 (/opt/hadoop3)　Hive 3.1.3 (/opt/hive3)　Tez 0.9.2 (/opt/tez-0.9.2)
> 日期：2026-08-22

本文档记录当天处理的三件事：① hive 客户端日志刷屏（**已修复**）；② 切换 MR 引擎执行报错（**已修复**）；③ 尝试启用 `hive.execution.engine=spark`（**经查证官方不支持 Hive 3.1.x 配 Spark 3.x，决定放弃，实验期间改动已全部回滚**）。当前环境为稳定的「mr + tez 双引擎 + spark-sql 直连」组合，三条通道均已验证通过。

---

## 问题一：`hive -e` 输出大量啰嗦的 INFO 日志

### 现象

执行 `hive -e ""` 时屏幕刷满 INFO 级别日志，查询结果被淹没，无法直观看结果。

### 根因

classpath 上同时存在两套 SLF4J 绑定，SLF4J 只会选用其中一套，实际选中的是 hadoop 的那套：

| jar | 绑定 | 结果 |
|-----|------|------|
| `/opt/hadoop3/share/hadoop/common/lib/slf4j-log4j12-1.7.25.jar` | log4j 1.x | **实际生效** |
| `/opt/hive3/lib/log4j-slf4j-impl-2.17.1.jar` | log4j2 | 未生效 |

于是所有日志都走 **Hadoop 的** `log4j.properties` 配置，以 INFO 级别直接打到 **stdout**。
这就是为什么修改 Hive 自己的 `hive-log4j2.properties` 完全无效——那个配置根本没被用上。

### 修复方法

**思路**：不改任何 jar（避免破坏依赖），通过 JVM 参数给 hive 客户端单独指定一份 log4j 1.x 配置，把级别压到 ERROR 并让日志走 stderr。

#### 改动 1：新增 `/opt/hive3/conf/client-log4j.properties`

```properties
log4j.rootLogger=ERROR,console

log4j.appender.console=org.apache.log4j.ConsoleAppender
log4j.appender.console.target=System.err
log4j.appender.console.layout=org.apache.log4j.PatternLayout
log4j.appender.console.layout.ConversionPattern=%d{ISO8601} %-5p %c{1}: %m%n

# 压掉 CLI 退出时 TezSessionState 打印的无害 interrupt 堆栈
log4j.logger.org.apache.hadoop.hive.ql.exec.tez.TezSessionState=FATAL
```

要点：
- `rootLogger=ERROR`：只保留错误级别日志；
- `target=System.err`：日志走 stderr，stdout 只剩查询结果；
- 最后一行专门消除退出 hive 时打印的一大段
  `InterruptedException ... TezSessionState` 堆栈（那是 Tez 会话关闭时的正常现象，不是错误）。

#### 改动 2：修改 `/opt/hive3/conf/hive-env.sh`

在文件末尾追加一行：

```bash
export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -Dlog4j.configuration=file:/opt/hive3/conf/client-log4j.properties"
```

原理：hive CLI 底层由 hadoop 启动，`HADOOP_CLIENT_OPTS` 会注入客户端 JVM，
`-Dlog4j.configuration=` 覆盖默认的 log4j 配置加载路径，使上面这份配置生效。

### 效果

- stdout：只剩查询结果本身；
- stderr：仅剩启动时的 5 行 SLF4J 双绑定提示 + Hive 正常进度条信息（属正常现象）。

> 注意：不要为了消掉 SLF4J 提示去删除/改名 slf4j jar 包——
> `/opt/tez-0.9.2/lib/slf4j-api-1.7.25.jar` 和 `slf4f-log4j12-1.7.25.jar` 是指向
> `/opt/hadoop3/share/hadoop/common/lib/` 的**软链接**，动了会断链导致 Tez 会话失败。

---

## 问题二：MR 引擎执行报 `NoSuchFieldError: HADOOP_CLASSPATH`

### 现象

```sql
set hive.execution.engine=mr;
select count(*) from demo.users;
```

报错：

```
FAILED: Execution Error, return code -101 from org.apache.hadoop.hive.ql.exec.mr.MapRedTask. HADOOP_CLASSPATH
java.lang.NoSuchFieldError: HADOOP_CLASSPATH
    at org.apache.hadoop.mapreduce.v2.util.MRApps.setClasspath(MRApps.java:248)
```

Tez 引擎完全正常，只有切到 MR 引擎才挂。

### 根因（有完整证据链）

1. `/opt/hive3/conf/hive-env.sh` 里配置 Tez 的循环代码把 `/opt/tez-0.9.2` 顶层和 `lib/`
   目录下的**全部** jar 拼成一个列表导出为 `HIVE_AUX_JARS_PATH`；
2. `/opt/hive3/bin/hive` 第 174 行把这个列表整段拼进 **CLI 进程自己的 classpath**
   （第 175 行另外生成 `--hiveconf hive.aux.jars.path=...` 参数，供 Tez AM 本地化资源使用）；
3. Tez 发行包自带旧版 hadoop 客户端：
   - `lib/hadoop-mapreduce-client-core-2.7.2.jar`
   - `lib/hadoop-mapreduce-client-common-2.7.2.jar`
   它们被塞进 CLI classpath 后，位置排在 hadoop3 自己的目录**前面**。
   实测证据：抓取运行中 JVM 的 `/proc/<PID>/environ` 分析 CLASSPATH 字节偏移——
   旧包位于 offset≈11855，hadoop3 的 `share/hadoop/mapreduce` 在 offset≈23733；
4. 用 `-verbose:class` 进一步证实：`MRJobConfig / MRApps / JobContext` 等
   `org.apache.hadoop.mapreduce.*` 类全部从 **2.7.2 的旧 jar** 加载；
5. 旧版类与 classpath 其余位置的 hadoop 3.1.1 类混用，提交作业时触发
   `NoSuchFieldError: HADOOP_CLASSPATH`。

### 排查过程中的弯路（重要教训）

| 尝试 | 结果 | 原因 |
|------|------|------|
| 把两个 2.7.2 jar 移出 `/opt/tez-0.9.2/lib` | MR 修好，但 Tez 反而报 jersey `InnerClasses attribute` 冲突 | CLI classpath 和 Tez AM 本地化列表读的是**同一个变量**，移走文件等于两边一起变 |
| 在 `HADOOP_CLASSPATH` 中前置 hadoop3 的 mapreduce 目录 | 无效 | hadoop 启动脚本会把用户 `HADOOP_CLASSPATH` 追加到 classpath **最末尾**，抢不过前面的 aux jar |
| `hive --service classpath` 查看 CP | 不存在该服务 | 可用服务里没有 classpath |

> 另外两个 jar 曾临时移到 `/root/jar-backup`，之后已放回原位。当前磁盘上没有任何文件被移动或缺失。

### 最终修复（只改一个文件的一行）

文件：`/opt/hive3/bin/hive`　　备份：`/opt/hive3/bin/hive.bak-mrfix`

原第 174 行：

```bash
  AUX_CLASSPATH=${AUX_CLASSPATH}:${HIVE_AUX_JARS_PATH}
```

改为：

```bash
  AUX_CLASSPATH=${AUX_CLASSPATH}:$(echo ${HIVE_AUX_JARS_PATH} | sed "s/:/\n/g" | grep -v "lib/hadoop-mapreduce-client-" | paste -sd: -)
```

**原理**：

- `AUX_CLASSPATH`（拼进 CLI classpath 的部分）过滤掉旧版 `hadoop-mapreduce-client-*` 包
  → CLI 不再加载 2.7.2 的类 → `org.apache.hadoop.mapreduce.*` 正常解析自
  hadoop3 的 `share/hadoop/mapreduce/*.jar` → MR 引擎提交恢复正常；
- `AUX_PARAM`（生成 `--hiveconf hive.aux.jars.path=` 的部分）**保持原样**
  → Tez AM 收到的本地化资源列表与改动前逐字节一致 → Tez 零影响；
- 全程未移动、未删除、未改名任何 jar 文件。

### 验证结果（双引擎同测通过）

| 引擎 | 查询 | 结果 |
|------|------|------|
| MR  | `set hive.execution.engine=mr; select count(*) from demo.users;` | **6040**　RC=0 ✓ |
| Tez | `select count(*) from demo.ratings` | **1000209**　RC=0 ✓ |

---

## 附：全部改动一览与回滚命令

| # | 文件 | 改动内容 | 备份文件 | 回滚命令 |
|---|------|----------|----------|----------|
| 1 | `/opt/hive3/conf/hive-env.sh` | 末尾追加 HADOOP_CLIENT_OPTS 一行（指定客户端 log4j 配置） | `hive-env.sh.bak-fix` | `cp -a /opt/hive3/conf/hive-env.sh.bak-fix /opt/hive3/conf/hive-env.sh` |
| 2 | `/opt/hive3/conf/client-log4j.properties` | 新增（ERROR 级别 + 日志走 stderr） | — | 直接删除该文件 |
| 3 | `/opt/hive3/bin/hive` | 第 174 行 AUX_CLASSPATH 过滤旧版 hadoop 包 | `hive.bak-mrfix` | `cp -a /opt/hive3/bin/hive.bak-mrfix /opt/hive3/bin/hive` |

## 注意事项

1. 不要移动 / 改名 `/opt/hadoop3/share/hadoop/common/lib/` 和 `/opt/tez-0.9.2/lib/`
   下的任何 jar（存在软链接且被 CLI 与 AM 双方共用）；
2. 以后升级 Hive / Tez / Hadoop 版本后，需重新确认 `/opt/hive3/bin/hive` 第 174 行补丁是否仍适用；
3. 若同时要改 hive 服务端（hiveserver2/metastore）日志，另行处理，勿复用本 client-log4j 方案直接套用。

---

## 问题三：`set hive.execution.engine=spark` 无法使用（官方不支持，放弃并回滚）

### 目标与现象

希望在 mr / tez / spark 三引擎间自由切换。但 `engine=spark` 时作业必然失败，driver 端真实报错为：

```
com.esotericsoftware.kryo.KryoException: Unable to find class: oot_<queryid>:1
（查询 ID 无故丢失首字母 r、尾部多出 ":1"，发生在反序列化 SparkWork.invertedWorkGraph 时）
```

### 结论：版本组合不受官方支持，不是配置问题

- Apache Hive 官方兼容矩阵中，**Hive 3.1.x 的 spark 引擎只保证配 Spark 2.3.0**（版本号写死在 Hive 源码根 pom.xml 的 `<spark.version>`）；本环境装的是 Spark 3.1.1，属"未测试组合"；
- 上述 kryo 报错是该组合的已知通病（BIGTOP-3641 记录了同款错误）；
- 社区唯一公认解法是**用改过 pom 的源码重编译 Hive**（`<spark.version>` 改 3.x、scala 改 2.12），替换 jar / 调配置均无法根治；
- 经决策放弃该路线。**Spark 计算的正确姿势是直接用 `spark-sql`**（读同一 metastore，本机已验证正常），即业界主流的 "Spark on Hive" 用法。

### 实验期间的改动已全部回滚

| 位置 | 实验时改动 | 回滚后状态 |
|------|-----------|-----------|
| `/opt/hive3/lib/` | 7 个 spark jar 换成 3.1.1、kryo-shaded 换成 4.0.2、新增 scala 2.12.10 | 已恢复原版：`spark-*-3.3.0` ×7、`kryo-shaded-3.0.3`、scala 仅 2.12.15 |
| `/opt/hive3/conf/hive-site.xml` | 追加 8 个 `spark.*` 配置项 | 从 `hive-site.xml.bak-spark` 整体恢复 |
| `/opt/spark2/jars/` | guava-14.0.1 换成 guava-19.0 | 已恢复 `guava-14.0.1.jar` |
| HDFS | 新建 `/spark-jars/` 目录（280 个 jar） | 已删除 |
| 其他 | `/opt/spark2/conf/driver-log4j.properties`、`/tmp/remotedriver.log` | 已删除 |

原始 jar 备份仍保留在服务器 `/root/jar-backup-spark/`（8 个 jar），日后若走源码重编译路线可参考。

### 回滚后最终验证（三条通道全绿）

| 入口 | 查询 | 结果 |
|------|------|------|
| hive CLI + MR 引擎 | `select count(*) from demo.users` | **6040**　RC=0 ✓ |
| hive CLI + Tez 引擎 | `select count(*) from demo.ratings` | **1000209**　RC=0 ✓ |
| spark-sql | `select count(*) from demo.ratings` | **1000209**　RC=0 ✓ |

> 若未来想真正启用 engine=spark：需使用社区改编译版 Hive 或自行源码重编译（pom 改 `spark.version=3.1.1` + scala 2.12），不要再走直接换 jar 的弯路。
