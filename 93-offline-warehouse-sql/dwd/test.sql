# 探查一下

select   * from  ods.ods_user_info  ;
select  u.user_id,count(1) as cnt   from  ods.ods_user_info  u  group by  u.user_id  having  count(1) >1  ;

select  * from  ods.ods_user_info  where   city=''  or  province =''  ;
select  * from  ods.ods_user_info  where   user_level=''  ;
select  * from  ods.ods_user_info u where   u.status=''  ;
--
-- 钱有问题
select  *  from  ods.ods_order_info  where  total_amount-discount_amount+freight_amount!=pay_amount;
select  *  from  ods.ods_order_info  where  payment_time<create_time  and  payment_time!='';

select o.detail_id,o.product_price*product_quantity,total_amount from ods.ods_order_detail  o where o.product_price*product_quantity!=total_amount;
-- 明细跟订单表的订单对的上吗
select distinct  o.order_id from  ods.ods_order_info   o
minus
select distinct  oi.order_id from  ods.ods_order_detail oi;


select distinct  oi.order_id from  ods.ods_order_detail oi
minus
select distinct  o.order_id from  ods.ods_order_info   o;

--价格对上了没有
select   o.order_id ,o.total_amount   from  ods.ods_order_info   o
minus
select  oi.order_id ,sum(oi.total_amount)  from  ods.ods_order_detail oi  group by oi.order_id;
/*
2000	1045.70
4223	8833.17
10269	2816.57
10979	1605.06
12837	172.56
*/

select * from ods.ods_order_info where order_id=2000;--1045.70

select order_id,sum(total_amount) from ods.ods_order_detail  where order_id=2000  group by order_id;
-- 订单的钱存在问题，可能需要手动来计算价格*数量
--
select * from ods.ods_product_info;

SELECT product_id, product_name
FROM ods.ods_product_info
WHERE replace(product_name,' ','') RLIKE '[^\\u4e00-\\u9fa5a-zA-Z0-9]';

---按每天的分区洗干净，以订单明细为主表
with code as 
(
    select * from dim.dim_code_value
),
 oi as (
        select  
        user_id,
        order_id,
        freight_amount,
        discount_amount,
        create_time,
        payment_time,
        payment_method,
        order_status,
        delivery_time,
        receive_time  
        from ods.ods_order_info  
        where order_status 
        between 1 and 3  
        and payment_time>create_time
)
select
   --用户信息
    ou.user_id,
    ou.username,
    if(ou.gender='1' ,'男',if(ou.gender='2','女','未知')) as gender,
    ou.age,
    concat(substr(
    regexp_extract(regexp_replace(replace(ou.phone,'+86',''),'[^0-9]',''),'(^1[3-9]\\d{9}$)',1),1,4),
    '****',
    substr(
    regexp_extract(regexp_replace(replace(ou.phone,'+86',''),'[^0-9]',''),'(^1[3-9]\\d{9}$)',1),-4,4))
     as phone,
    if(ou.city='','未知城市',ou.city) as city,
    if(ou.province='','未知省份',ou.province) as province,
    ou.register_date,
    case ou.register_channel when  'APP' then 'APP端'  when 'PC' then 'PC端' else '小程序' END register_channel,
    c1.code_label as  user_level,
    if(ou.status='0','禁用','正常' ) as  status,
   --订单信息
   oi.order_id,
   oi.freight_amount,
   oi.discount_amount,
   oi.create_time,
   oi.payment_time,
   c2.code_label as payment_method,
   c3.code_label as  order_status,
   oi.delivery_time,
   oi.receive_time,
   od.product_price*od.product_quantity as order_product_amount,
   sum(od.product_price*od.product_quantity) over (partition by od.order_id) as order_total_amount,
   sum(od.product_price*od.product_quantity) over (partition by od.order_id)-oi.discount_amount+oi.freight_amount as order_pay_amount,
   -- 产品信息
   opi.product_name  ,
   -- 类别
   ci.category_name,
   -- 品牌
   bi.brand_name
from oi 
left join ods.ods_order_detail od  on  od.order_id=oi.order_id
left join ods.ods_user_info    ou   on   ou.user_id=oi.user_id
left join ods.ods_product_info opi  on  od.product_id=opi.product_id
left join ods.ods_category_info ci  on  ci.category_id=opi.category_id
left join ods.ods_brand_info    bi  on  bi.brand_id=opi.brand_id
left join code c1 on c1.code_value=ou.user_level   and c1.code_group='user_level'
left join code c2 on c2.code_value=oi.payment_method   and c2.code_group='payment_method'
left join code c3 on c3.code_value= oi.order_status   and c3.code_group='order_status';