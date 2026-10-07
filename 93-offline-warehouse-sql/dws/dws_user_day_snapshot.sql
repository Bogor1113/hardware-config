-- 开启 Tez 小文件合并
set hive.merge.tezfiles = true;
-- 当输出平均文件小于 128MB 时触发合并
set hive.merge.smallfiles.avgsize = 134217728;
-- 合并后的目标文件大小设为 256MB
set hive.merge.size.per.task = 268435456;
create database if not exists dws;

create table if not exists  dws.dws_user_day_snapshot(
user_id           bigint,
day_order_count   int,
day_order_amount  decimal(10,2),
day_pay_count     int,
day_pay_amount    decimal(10,2), 
total_order_count   int,
total_pay_amount    decimal(10,2)
)
partitioned by (dt string)
row format delimited fields terminated by '\t'
stored as orc;



---
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '${hiveconf:dt}'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='${hiveconf:dt}')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '${hiveconf:dt}', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '${hiveconf:dt}', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '${hiveconf:dt}' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '${hiveconf:dt}' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;