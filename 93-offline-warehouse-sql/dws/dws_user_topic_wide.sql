-- 开启 Tez 小文件合并
set hive.merge.tezfiles = true;
-- 当输出平均文件小于 128MB 时触发合并
set hive.merge.smallfiles.avgsize = 134217728;
-- 合并后的目标文件大小设为 256MB
set hive.merge.size.per.task = 268435456;
create database
if not exists dws;
    CREATE table if not exists dws.dws_user_topic_wide
        (
            -- ========== 用户维度 ==========
            user_id          BIGINT COMMENT '用户ID',
            username         STRING COMMENT '用户名' ,
            gender           STRING COMMENT '性别'  ,
            age              INT COMMENT '年龄'     ,
            phone            STRING COMMENT '手机号' ,
            city             STRING COMMENT '城市'  ,
            province         STRING COMMENT '省份'  ,
            register_date    STRING COMMENT '注册日期',
            register_channel STRING COMMENT '注册渠道',
            user_level       STRING COMMENT '用户等级',
            status           STRING COMMENT '用户状态',
            -- ========== 订单行为指标 ==========
            first_order_date       STRING COMMENT '首次下单日期'        ,
            last_order_date        STRING COMMENT '最近下单日期'        ,
            first_pay_date         STRING COMMENT '首次支付日期'        ,
            last_pay_date          STRING COMMENT '最近支付日期'        ,
            order_count            BIGINT COMMENT '累计订单数'         ,
            total_order_amount     DECIMAL(20,2) COMMENT '累计订单总金额',
            pay_order_count        BIGINT COMMENT '累计支付订单数'       ,
            total_pay_amount       DECIMAL(20,2) COMMENT '累计支付总金额',
            is_current_order_ct    BIGINT COMMENT '当日下单数'         ,
            is_current_order_amout DECIMAL(20,2) COMMENT '当日下单金额' ,
            is_current_pay_ct      BIGINT COMMENT '当日支付数'         ,
            is_current_pay_amout   DECIMAL(20,2) COMMENT '当日支付金额' ,
            is_current_avg_price   DECIMAL(20,2) COMMENT '当日客单价'  ,
            -- =====偏好
            brand_fav    array<STRING> COMMENT '品牌偏好',
            category_fav array<STRING> COMMENT '品类偏好',
            payment_fav  array<string> COMMENT '支付偏好',
            --  分层，运营策略
            r                       double,
            f                       int   ,
            user_segment            string,
            user_operation_strategy string
        )
    STORED AS ORC;
    ---采用临时表，本次会话中可以用，但是会话一旦结束，表就没了空间释放回收,分开计算，减轻集群的计算压力
    -- 用户偏好
    create TEMPORARY table if not exists tmp_user_fav as
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
    ---计算用户rfm
    create TEMPORARY table if not exists tmp_user_rfm as
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
                CAST(PERCENTILE_APPROX(r, 0.5) AS BIGINT) as avg_r,
                CAST(PERCENTILE_APPROX(f, 0.5) AS BIGINT) as avg_f,
                CAST(PERCENTILE_APPROX(m, 0.5) AS BIGINT) as avg_m
            from b)
    select  /*+ MAPJOIN(c) */
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
    cross  join
        c;
    --- 插入宽表数据
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
    insert overwrite
    table
        dws.dws_user_topic_wide
    select
        a.user_id
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
        sum(if (datediff(current_Date,date(create_time))=1,1,0))                                                                                        as is_current_order_ct
        ,
        sum(if (datediff(current_Date,date(create_time))=1,order_total_amount,0))                                                                       as is_current_order_amout
        ,
        sum(if (datediff(current_Date,date(payment_time))=1,1,0))                                                                                       as is_current_pay_ct
        ,
        sum(if (datediff(current_Date,date(payment_time))=1,order_pay_amount,0))                                                                        as is_current_pay_amout
        ,
        round( sum(if (datediff(current_Date,date(create_time))=1,order_total_amount,0)) /
         sum(if (datediff(current_Date,date(create_time))=1,1,0)) ,2) as is_current_avg_price
        ,
        max(brand_fav )                                                                                                                                 as brand_fav
        ,
        max(category_fav)                                                                                                                               as category_fav
        ,
        max(pay_fav )                                                                                                                               as payment_fav
        ,
        --  分层，运营策略
        max(r )                                                                                                                                         as r
        ,
        max(f)                                                                                                                                          as f
        ,
        max(user_segment)                                                                                                                               as user_segment
        ,
        max(user_operation_strategy )                                                                                                                   as user_operation_strategy
    from
        a
    left join
        tmp_user_fav f
    on
        a.user_id=f.user_id
    left join
        tmp_user_rfm r
    on
        a.user_id=r.user_id
    group by
        a.user_id
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