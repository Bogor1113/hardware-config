-- Active: 1791263682819@@127.0.0.1@10000@default
--- 计算偏好  品牌  类别  支付
select
    *
from
    dwd.dwd_user_order_clean;---78499 阿杰 微信
with a as
     (
         select
             user_id
             ,
             collect_list(concat(payment_method,":",rk)) as pay_fav
         from
             (
                 select
                     user_id
                     ,
                     payment_method
                     ,
                     rank()over
                         (
                             partition by
                                 user_id
                             order by
                                 count(1) desc
                         )
                     as rk
                 from
                     dwd.dwd_user_order_clean
                 group by
                     user_id
                     ,
                     payment_method) a
         where
             rk = 1
         group by
             user_id)
     --品牌
     ,
     b as
     (
         select
             user_id
             ,
             collect_list(concat(brand_name,":",rk)) as brand_fav
         from
             (
                 select
                     user_id
                     ,
                     brand_name
                     ,
                     rank()over
                         (
                             partition by
                                 user_id
                             order by
                                 count(1) desc
                         )
                     as rk
                 from
                     dwd.dwd_user_order_clean
                 group by
                     user_id
                     ,
                     brand_name) a
         where
             rk = 1
         group by
             user_id)
     --类别
     ,
     c as
     (
         select
             user_id
             ,
             collect_list(concat(category_name,':',rk)) as category_fav
         from
             (
                 select
                     user_id
                     ,
                     category_name
                     ,
                     rank()over
                         (
                             partition by
                                 user_id
                             order by
                                 count(1) desc
                         )
                     as rk
                 from
                     dwd.dwd_user_order_clean
                 group by
                     user_id
                     ,
                     category_name) a
         where
             rk = 1
         group by
             user_id)
select
    a.user_id
    ,
    a.pay_fav
    ,
    b.brand_fav
    ,
    c.category_fav
from
    a
join
    b
on
    a.user_id = b.user_id
join
    c
on
    a.user_id = c.user_id;
-- 计算rfm模型   8个用户分层    重要价值  一般挽留  流失...
--基于 RFM 模型做 8 个用户分层，通常是把 R（最近一次消费）、F（消费频率）、M（消费金额）三个维度
with a as
     (
         select
             u.user_id
             ,
             u.create_time
             ,
             u.order_id
             ,
             u.order_pay_amount
         from
             dwd.dwd_user_order_clean u
         group by
             u.user_id
             ,
             u.create_time
             ,
             u.order_id
             ,
             u.order_pay_amount)
     --- 计算所有的用户情况是怎么样呢？
     ,
     b as
     (
         select
             user_id
             ,
             datediff(current_date,max(create_time)) as r
             ,
             count(1)                                as f
             ,
             sum(order_pay_amount)                   as m
         from
             a
         group by
             user_id)
     --所有用户的 二分位情况
     ,
     c as
     (
         select
             PERCENTILE_APPROX(r,0.5) as avg_r
             ,
             PERCENTILE_APPROX(f,0.5) as avg_f
             ,
             PERCENTILE_APPROX(m,0.5) as avg_m
         from
             b)
select
    b.user_id
    ,
    b.r
    ,
    b.f
    ,
    b.m
    ,
    case
        when
            r<=c.avg_r
        and f>=c.avg_f
        and m>=c.avg_m
        then '重要价值客户'
        when
            r<=c.avg_r
        and f<c.avg_f
        and m>=c.avg_m
        then '重要发展客户'
        when
            r>c.avg_r
        and f>=c.avg_f
        and m>=c.avg_m
        then '重要保持客户'
        when
            r>c.avg_r
        and f<c.avg_f
        and m>=c.avg_m
        then '重要挽留客户'
        when
            r<=c.avg_r
        and f>=c.avg_f
        and m<c.avg_m
        then '一般价值客户'
        when
            r<=c.avg_r
        and f<c.avg_f
        and m<c.avg_m
        then '一般发展客户'
        when
            r>c.avg_r
        and f>=c.avg_f
        and m<c.avg_m
        then '一般保持客户'
        when
            r>c.avg_r
        and f<c.avg_f
        and m<c.avg_m
        then '一般挽留客户'
        else '其他'
    end user_segment
    ,
    case
        when
            r<=c.avg_r
        and f>=c.avg_f
        and m>=c.avg_m
        then '重点维护，VIP 服务'
        when
            r<=c.avg_r
        and f<c.avg_f
        and m>=c.avg_m
        then '提升消费频次'
        when
            r>c.avg_r
        and f>=c.avg_f
        and m>=c.avg_m
        then '唤回，防止流失'
        when
            r>c.avg_r
        and f<c.avg_f
        and m>=c.avg_m
        then '强唤回，优惠刺激'
        when
            r<=c.avg_r
        and f>=c.avg_f
        and m<c.avg_m
        then '提升客单价'
        when
            r<=c.avg_r
        and f<c.avg_f
        and m<c.avg_m
        then '培养消费习惯'
        when
            r>c.avg_r
        and f>=c.avg_f
        and m<c.avg_m
        then '提升客单价 + 唤回'
        when
            r>c.avg_r
        and f<c.avg_f
        and m<c.avg_m
        then '低成本触达或放弃'
        else '其他'
    end user_operation_strategy
from
    b
join
    c
on
    1=1;
--- 宽表其他信息
with a as
     (
         select
             u.user_id
             ,
             u.username
             ,
             u.gender
             ,
             u.age
             ,
             if (u.phone!='****',u.phone,'') as phone
             ,
             u.city
             ,
             u.province
             ,
             u.register_date
             ,
             u.register_channel
             ,
             u.user_level
             ,
             u.status
             ,
             u.create_time
             ,
             u.payment_time
             ,
             u.order_id
             ,
             u.order_pay_amount
             ,
             u.order_total_amount
         from
             dwd.dwd_user_order_clean u
         group by
             u.user_id
             ,
             u.username
             ,
             u.gender
             ,
             u.age
             ,
             if (u.phone!='****',u.phone,'')
             ,
             u.city
             ,
             u.province
             ,
             u.register_date
             ,
             u.register_channel
             ,
             u.user_level
             ,
             u.status
             ,
             u.create_time
             ,
             u.payment_time
             ,
             u.order_id
             ,
             u.order_pay_amount
             ,
             u.order_total_amount )
select
    user_id
    ,
    username
    ,
    gender
    ,
    age
    ,
    phone
    ,
    city
    ,
    province
    ,
    register_date
    ,
    register_channel
    ,
    user_level
    ,
    status
    ,
    date(min(create_time))                                                                                                                          as first_order_date
    ,
    date(max(create_time))                                                                                                                          as last_order_date
    ,
    date(min(payment_time))                                                                                                                         as first_pay_date
    ,
    date(max(payment_time))                                                                                                                         as last_pay_date
    ,
    count(order_id)                                                                                                                                 as order_count
    ,
    sum(order_total_amount)                                                                                                                         as total_order_amount
    ,
    sum(if (payment_time is not null
    or payment_time!='',1,0))                                                                                                                       as pay_order_count
    ,
    sum(order_pay_amount)                                                                                                                           as total_pay_amount
    ,
    sum(if (datediff(current_Date,date(create_time))=3,1,0))                                                                                        as is_current_order_ct
    ,
    sum(if (datediff(current_Date,date(create_time))=3,order_total_amount,0))                                                                       as is_current_order_amout
    ,
    sum(if (datediff(current_Date,date(payment_time))=3,1,0))                                                                                       as is_current_pay_ct
    ,
    sum(if (datediff(current_Date,date(payment_time))=3,order_pay_amount,0))                                                                        as is_current_pay_amout
    ,
    round( sum(if (datediff(current_Date,date(create_time))=3,order_total_amount,0)) /
     sum(if (datediff(current_Date,date(create_time))=3,1,0)) ,2) as is_current_avg_price
from
    a
group by
    user_id
    ,
    username
    ,
    gender
    ,
    age
    ,
    phone
    ,
    city
    ,
    province
    ,
    register_date
    ,
    register_channel
    ,
    user_level
    ,
    status ;



    select * from dwd.dwd_user_order_clean  where user_id=10000;--2105259  
    select * from dws.dws_user_topic_wide;-- where user_id=10000 ;---188566
    select * from dws.dws_user_topic_wide where user_id=1;
    /*
    user_id (??ID)	1
    username (???)	小红3241
    gender (??)	女
    age (??)	45
    phone (???)	1980****6283
    city (??)	厦门
    province (??)	福建省
    register_date (????)	2026-09-27
    register_channel (????)	PC端
    user_level (????)	普通会员
    status (????)	正常
    first_order_date (??????)	2026-09-26
    last_order_date (??????)	2026-10-03
    first_pay_date (??????)	2026-09-26
    last_pay_date (??????)	2026-10-04
    order_count (?????)	25149
    total_order_amount (???????)	180766769.68
    pay_order_count (???????)	25149
    total_pay_amount (???????)	162880021.31
    is_current_order_ct (?????)	0
    is_current_order_amout (??????)	0.00
    is_current_pay_ct (?????)	34
    is_current_pay_amout (??????)	162294.05
    is_current_avg_price (?????)	
    brand_fav (????)	["MUJI:1"]
    category_fav (????)	["面部护肤:1"]
    payment_fav (????)	["支付宝:1"]
    r	1.0
    f	25149
    user_segment	重要保持客户
    user_operation_strategy	重点维护，VIP 服务
*/