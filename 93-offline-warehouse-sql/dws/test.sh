#!/bin/bash
# =============================================================
# dws 层批量构建：单次 beeline session 串行跑全部 11 天
# 原理：整个批次只向 YARN 申请 1 个 Tez AM，11 个 insert 复用同一会话，
#       避免逐条提交时每次都要重新申请 AM / 排队。
# 用法：./test.sh
# =============================================================
set -o pipefail
export PATH=/opt/hive3/bin:/opt/hadoop3/bin:$PATH
cd "$(dirname "$0")" || exit 1

beeline -u jdbc:hive2://localhost:10000/default -n root \
        --silent=true --showHeader=false --outputformat=tsv2 \
        -f all_days_one_session.sql 2>&1 \
  | sed '/^SLF4J/d' \
  | sed '/^[[:space:]]*$/d'

exit ${PIPESTATUS[0]}
