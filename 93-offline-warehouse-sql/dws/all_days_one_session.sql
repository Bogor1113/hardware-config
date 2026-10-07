set hive.merge.tezfiles = true;
set hive.merge.smallfiles.avgsize = 134217728;
set hive.merge.size.per.task = 268435456;


-- ===== 2026-09-26 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-09-26'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-09-26')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-09-26', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-09-26', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-09-26' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-09-26' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-09-27 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-09-27'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-09-27')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-09-27', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-09-27', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-09-27' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-09-27' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-09-28 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-09-28'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-09-28')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-09-28', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-09-28', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-09-28' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-09-28' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-09-29 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-09-29'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-09-29')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-09-29', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-09-29', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-09-29' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-09-29' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-09-30 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-09-30'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-09-30')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-09-30', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-09-30', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-09-30' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-09-30' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-10-01 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-10-01'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-10-01')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-10-01', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-10-01', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-10-01' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-10-01' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-10-02 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-10-02'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-10-02')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-10-02', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-10-02', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-10-02' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-10-02' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-10-03 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-10-03'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-10-03')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-10-03', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-10-03', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-10-03' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-10-03' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-10-04 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-10-04'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-10-04')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-10-04', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-10-04', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-10-04' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-10-04' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-10-05 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-10-05'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-10-05')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-10-05', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-10-05', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-10-05' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-10-05' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;

-- ===== 2026-10-06 =====
with a as (
    select
        u.user_id,
        u.create_time,
        u.payment_time,
        u.order_id,
        u.order_pay_amount,
        u.order_total_amount
    from dwd.dwd_user_order_clean u
    where dt <= '2026-10-06'          -- ✅ 关键：扫历史所有分区
    group by
        u.user_id, u.create_time, u.payment_time,
        u.order_id, u.order_pay_amount, u.order_total_amount
)
insert overwrite table dws.dws_user_day_snapshot partition (dt='2026-10-06')
select
    a.user_id,
    -- 当日指标：只看当天（用 create_time / payment_time 过滤）
    count(if(substr(create_time,1,10) = '2026-10-06', order_id, null)) as day_order_count,
    sum(if(substr(create_time,1,10) = '2026-10-06', order_total_amount, 0)) as day_order_amount,
    sum(if(substr(payment_time,1,10) = '2026-10-06' and payment_time != '', 1, 0)) as day_pay_count,
    sum(if(substr(payment_time,1,10) = '2026-10-06' and payment_time != '', order_pay_amount, 0)) as day_pay_amount,
    -- 累计指标：截止到当天全部历史
    count(order_id)             as total_order_count,
    sum(order_total_amount)     as total_order_amount
from a
group by a.user_id;
