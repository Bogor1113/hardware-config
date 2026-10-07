-- ============================================================
-- DWS 用户主题宽表 ETL
-- 优化点：
--   1. 明细表只扫描 2 次（订单+维度 1 次、偏好 1 次）
--   2. 先聚合到订单粒度，后续计算量下降一个数量级
--   3. 最终只按 user_id 关联，避免全维度字段 group by
--   4. 修复 or 恒真、除零、bigint/double 比较警告
-- ============================================================

-- ========== 参数配置 ==========
-- Tez 小文件合并
set hive.merge.tezfiles = true;
set hive.merge.smallfiles.avgsize = 134217728;
set hive.merge.size.per.task = 268435456;
-- Reducer 数量控制
set hive.exec.reducers.bytes.per.reducer = 268435456;
set hive.exec.reducers.max = 1009;
-- MapJoin 自动转换
set hive.auto.convert.join = true;
set hive.auto.convert.join.noconditionaltask = true;
set hive.auto.convert.join.noconditionaltask.size = 50000000;


create database if not exists dws;

-- ========== 建表 ==========
CREATE TABLE IF NOT EXISTS dws.dws_user_topic_wide (
    -- 用户维度
    user_id                 BIGINT        COMMENT '用户ID',
    username                STRING        COMMENT '用户名',
    gender                  STRING        COMMENT '性别',
    age                     INT           COMMENT '年龄',
    phone                   STRING        COMMENT '手机号',
    city                    STRING        COMMENT '城市',
    province                STRING        COMMENT '省份',
    register_date           STRING        COMMENT '注册日期',
    register_channel        STRING        COMMENT '注册渠道',
    user_level              STRING        COMMENT '用户等级',
    status                  STRING        COMMENT '用户状态',
    -- 订单行为指标
    first_order_date        STRING        COMMENT '首次下单日期',
    last_order_date         STRING        COMMENT '最近下单日期',
    first_pay_date          STRING        COMMENT '首次支付日期',
    last_pay_date           STRING        COMMENT '最近支付日期',
    order_count             BIGINT        COMMENT '累计订单数',
    total_order_amount      DECIMAL(20,2) COMMENT '累计订单总金额',
    pay_order_count         BIGINT        COMMENT '累计支付订单数',
    total_pay_amount        DECIMAL(20,2) COMMENT '累计支付总金额',
    is_current_order_ct     BIGINT        COMMENT '当日下单数',
    is_current_order_amout  DECIMAL(20,2) COMMENT '当日下单金额',
    is_current_pay_ct       BIGINT        COMMENT '当日支付数',
    is_current_pay_amout    DECIMAL(20,2) COMMENT '当日支付金额',
    is_current_avg_price    DECIMAL(20,2) COMMENT '当日客单价',
    -- 偏好
    brand_fav               ARRAY<STRING> COMMENT '品牌偏好',
    category_fav            ARRAY<STRING> COMMENT '品类偏好',
    payment_fav             ARRAY<STRING> COMMENT '支付偏好',
    -- 分层与策略
    r                       DOUBLE        COMMENT 'R值(最近消费距今天数)',
    f                       INT           COMMENT 'F值(消费频次)',
    user_segment            STRING        COMMENT '用户分层',
    user_operation_strategy STRING        COMMENT '运营策略'
)
COMMENT 'DWS层-用户主题宽表'
STORED AS ORC
TBLPROPERTIES ('orc.compress' = 'SNAPPY');--默认zilib


-- ============================================================
-- 1. 订单粒度聚合 + 用户维度透传（明细表扫描第 1 次）
--    输出：每个 user_id + order_id 一行，同时带上该用户维度
-- ============================================================
create TEMPORARY table if not exists tmp_order_and_dim as
select
    user_id,
    order_id,
    min(create_time)        as create_time,
    min(payment_time)       as payment_time,
    sum(order_pay_amount)   as order_pay_amount,
    sum(order_total_amount) as order_total_amount,
    -- 用户维度：同用户所有订单值相同，用 max 透传
    max(username)           as username,
    max(gender)             as gender,
    max(age)                as age,
    max(if(phone != '****', phone, '')) as phone,
    max(city)               as city,
    max(province)           as province,
    max(register_date)      as register_date,
    max(register_channel)   as register_channel,
    max(user_level)         as user_level,
    max(status)             as status
from dwd.dwd_user_order_clean
group by user_id, order_id;


-- ============================================================
-- 2. 用户维度表（每用户一行）
-- ============================================================
create TEMPORARY table if not exists tmp_user_dim as
select
    user_id,
    max(username)          as username,
    max(gender)            as gender,
    max(age)               as age,
    max(phone)             as phone,
    max(city)              as city,
    max(province)          as province,
    max(register_date)     as register_date,
    max(register_channel)  as register_channel,
    max(user_level)        as user_level,
    max(status)            as status
from tmp_order_and_dim
group by user_id;


-- ============================================================
-- 3. 用户订单指标（基于订单粒度）
-- ============================================================
create TEMPORARY table if not exists tmp_user_metrics as
select
    user_id,
    date(min(create_time))  as first_order_date,
    date(max(create_time))  as last_order_date,
    date(min(payment_time)) as first_pay_date,
    date(max(payment_time)) as last_pay_date,
    count(order_id)         as order_count,
    sum(order_total_amount) as total_order_amount,
    -- 修正：or 改 and
    sum(if(payment_time is not null and payment_time != '', 1, 0)) as pay_order_count,
    sum(order_pay_amount)   as total_pay_amount,
    -- 当日口径（T-3）
    sum(if(datediff(current_date, date(create_time))  = 3, 1, 0))                  as is_current_order_ct,
    sum(if(datediff(current_date, date(create_time))  = 3, order_total_amount, 0)) as is_current_order_amout,
    sum(if(datediff(current_date, date(payment_time)) = 3, 1, 0))                  as is_current_pay_ct,
    sum(if(datediff(current_date, date(payment_time)) = 3, order_pay_amount, 0))   as is_current_pay_amout,
    -- 除零保护
    round(
        sum(if(datediff(current_date, date(create_time)) = 3, order_total_amount, 0))
        / nullif(sum(if(datediff(current_date, date(create_time)) = 3, 1, 0)), 0)
    , 2) as is_current_avg_price
from tmp_order_and_dim
group by user_id;


-- ============================================================
-- 4. 用户偏好：一次扫描算出三维度 Top3（明细表扫描第 2 次）
-- ============================================================
create TEMPORARY table if not exists tmp_user_fav as
select
    p.user_id,
    p.pay_fav,
    b.brand_fav,
    c.category_fav
from (
    -- 支付方式 Top3
    select
        user_id,
        collect_list(payment_method) as pay_fav
    from (
        select
            user_id,
            payment_method,
            count(1) as cnt,
            row_number() over (partition by user_id order by count(1) desc) as rn
        from dwd.dwd_user_order_clean
        where payment_method is not null and payment_method != ''
        group by user_id, payment_method
    ) t
    where rn <= 3
    group by user_id
) p
full join (
    -- 品牌 Top3
    select
        user_id,
        collect_list(brand_name) as brand_fav
    from (
        select
            user_id,
            brand_name,
            count(1) as cnt,
            row_number() over (partition by user_id order by count(1) desc) as rn
        from dwd.dwd_user_order_clean
        where brand_name is not null and brand_name != ''
        group by user_id, brand_name
    ) t
    where rn <= 3
    group by user_id
) b on p.user_id = b.user_id
full join (
    -- 品类 Top3
    select
        user_id,
        collect_list(category_name) as category_fav
    from (
        select
            user_id,
            category_name,
            count(1) as cnt,
            row_number() over (partition by user_id order by count(1) desc) as rn
        from dwd.dwd_user_order_clean
        where category_name is not null and category_name != ''
        group by user_id, category_name
    ) t
    where rn <= 3
    group by user_id
) c on p.user_id = c.user_id;


-- ============================================================
-- 5. RFM 计算
-- ============================================================
create TEMPORARY table if not exists tmp_user_rfm as
with b as (
    select
        user_id,
        datediff(current_date, max(create_time)) as r,
        count(1)                                 as f,
        sum(order_pay_amount)                    as m
    from tmp_order_and_dim
    group by user_id
),
c as (
    select
        CAST(PERCENTILE_APPROX(r, 0.5) AS BIGINT) as avg_r,
        CAST(PERCENTILE_APPROX(f, 0.5) AS BIGINT) as avg_f,
        CAST(PERCENTILE_APPROX(m, 0.5) AS BIGINT) as avg_m
    from b
)
select /*+ MAPJOIN(c) */
    b.user_id,
    b.r,
    b.f,
    case
        when b.r <= c.avg_r and b.f >= c.avg_f and b.m >= c.avg_m then '重要价值客户'
        when b.r <= c.avg_r and b.f <  c.avg_f and b.m >= c.avg_m then '重要发展客户'
        when b.r >  c.avg_r and b.f >= c.avg_f and b.m >= c.avg_m then '重要保持客户'
        when b.r >  c.avg_r and b.f <  c.avg_f and b.m >= c.avg_m then '重要挽留客户'
        when b.r <= c.avg_r and b.f >= c.avg_f and b.m <  c.avg_m then '一般价值客户'
        when b.r <= c.avg_r and b.f <  c.avg_f and b.m <  c.avg_m then '一般发展客户'
        when b.r >  c.avg_r and b.f >= c.avg_f and b.m <  c.avg_m then '一般保持客户'
        when b.r >  c.avg_r and b.f <  c.avg_f and b.m <  c.avg_m then '一般挽留客户'
        else '其他'
    end as user_segment,
    case
        when b.r <= c.avg_r and b.f >= c.avg_f and b.m >= c.avg_m then '重点维护，VIP 服务'
        when b.r <= c.avg_r and b.f <  c.avg_f and b.m >= c.avg_m then '提升消费频次'
        when b.r >  c.avg_r and b.f >= c.avg_f and b.m >= c.avg_m then '唤回，防止流失'
        when b.r >  c.avg_r and b.f <  c.avg_f and b.m >= c.avg_m then '强唤回，优惠刺激'
        when b.r <= c.avg_r and b.f >= c.avg_f and b.m <  c.avg_m then '提升客单价'
        when b.r <= c.avg_r and b.f <  c.avg_f and b.m <  c.avg_m then '培养消费习惯'
        when b.r >  c.avg_r and b.f >= c.avg_f and b.m <  c.avg_m then '提升客单价 + 唤回'
        when b.r >  c.avg_r and b.f <  c.avg_f and b.m <  c.avg_m then '低成本触达或放弃'
        else '其他'
    end as user_operation_strategy
from b
cross join c;


-- ============================================================
-- 6. 合并落宽表
-- ============================================================
insert overwrite table dws.dws_user_topic_wide
select
    d.user_id,
    d.username,
    d.gender,
    d.age,
    d.phone,
    d.city,
    d.province,
    d.register_date,
    d.register_channel,
    d.user_level,
    d.status,
    m.first_order_date,
    m.last_order_date,
    m.first_pay_date,
    m.last_pay_date,
    m.order_count,
    m.total_order_amount,
    m.pay_order_count,
    m.total_pay_amount,
    m.is_current_order_ct,
    m.is_current_order_amout,
    m.is_current_pay_ct,
    m.is_current_pay_amout,
    m.is_current_avg_price,
    fav.brand_fav,
    fav.category_fav,
    fav.pay_fav,
    rfm.r,
    rfm.f,
    rfm.user_segment,
    rfm.user_operation_strategy
from tmp_user_dim d
left join tmp_user_metrics m on d.user_id = m.user_id
left join tmp_user_fav     fav on d.user_id = fav.user_id
left join tmp_user_rfm     rfm on d.user_id = rfm.user_id;


-- ============================================================
-- 7. 验证（可选）
-- ============================================================
-- 分层人数与金额占比
-- select
--     user_segment,
--     count(1) as user_cnt,
--     round(count(1) / sum(count(1)) over () * 100, 2) as user_pct,
--     sum(total_pay_amount) as total_amount,
--     round(sum(total_pay_amount) / sum(sum(total_pay_amount)) over () * 100, 2) as amount_pct
-- from dws.dws_user_topic_wide
-- group by user_segment
-- order by amount_pct desc;

-- 总行数
-- select count(1) from dws.dws_user_topic_wide;