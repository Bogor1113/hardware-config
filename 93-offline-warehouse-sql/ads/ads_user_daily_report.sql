
create DATABASE if not EXISTS  ads;


CREATE TABLE IF NOT EXISTS ads.ads_user_daily_report (
    stat_date                 STRING      COMMENT '统计日期',
    valid_users_count         BIGINT      COMMENT '有效用户数（有首单日期的用户）',
    daily_active_users        BIGINT      COMMENT '日活跃用户数（当日下单用户）',
    order_count               BIGINT      COMMENT '订单量',
    order_amount              DECIMAL(20,2) COMMENT '订单金额',
    pay_order_count           BIGINT      COMMENT '支付订单数',
    pay_amount                DECIMAL(20,2) COMMENT '支付金额',
    order_conversion_rate     DECIMAL(20,4) COMMENT '下单转化率 = 订单量/有效用户数',
    pay_conversion_rate       DECIMAL(20,4) COMMENT '支付转化率 = 支付订单数/有效用户数',
    avg_order_amount          DECIMAL(20,2) COMMENT '人均订单金额 = 总订单金额/有效用户数',
    order_count_wow_rate      DECIMAL(20,2) COMMENT '订单量环比增长率(%)',
    pay_amount_wow_rate       DECIMAL(20,2) COMMENT '支付金额环比增长率(%)'
)
STORED AS textfile;

with before_yesterday as(
    select  sum(u.day_order_count) as before_yesterday_order_ct,
    sum(u.day_pay_amount) as before_yesterday_pay_amount
    from  dws.dws_user_day_snapshot  u
    where dt=date_sub(current_date,2)
)
insert overwrite table ads.ads_user_daily_report
select
    current_date  as stat_date,
    sum(if (u.first_order_date is not null  or u.first_order_date!='',1,0)) as valid_users_count,
    count(if(u.is_current_order_ct!=0,1,null)) as daily_active_users,
    sum(u.is_current_order_ct) as order_count,
    sum(u.is_current_order_amout) as order_amount,
    count(if(u.is_current_pay_ct!=0,1,null)) as pay_order_count,
    sum(u.is_current_pay_amout) as pay_amount,
    sum(u.is_current_order_ct)/
        sum(if (u.first_order_date is not null  or u.first_order_date!='',1,0)) as order_conversion_rate,
    sum(u.is_current_pay_ct)/
        sum(if (u.first_order_date is not null  or u.first_order_date!='',1,0)) as pay_conversion_rate,
    sum(u.total_order_amount)/
        sum(if (u.first_order_date is not null  or u.first_order_date!='',1,0)) as avg_order_amount,
    (sum(u.is_current_order_ct)-max(y.before_yesterday_order_ct))/max(y.before_yesterday_order_ct)*100 as order_count_wow_rate,
    (sum(u.is_current_pay_amout)-max(y.before_yesterday_pay_amount))/max(y.before_yesterday_pay_amount)*100 as pay_amount_wow_rate
from  dws.dws_user_topic_wide u 
cross  join before_yesterday  y;



-- 分层的统计