
create database  if not exists  ods;



drop  table  if exists  ods.ods_order_info;

CREATE TABLE IF NOT EXISTS ods.ods_order_info
(
    `order_id`         BIGINT   COMMENT '订单ID',
    `order_no`         STRING   COMMENT '订单编号',
    `user_id`          BIGINT   COMMENT '用户ID',
    `total_amount`     DECIMAL(12,2) COMMENT '订单总金额',
    `pay_amount`       DECIMAL(12,2) COMMENT '实付金额',
    `freight_amount`   DECIMAL(10,2) COMMENT '运费',
    `discount_amount`  DECIMAL(10,2) COMMENT '优惠金额',
    `coupon_id`        BIGINT   COMMENT '优惠券ID',
    `order_status`     TINYINT  COMMENT '订单状态：0待付款 1已付款 2已发货 3已完成 4已取消',
    `payment_method`   STRING   COMMENT '支付方式',
    `payment_time`     STRING   COMMENT '支付时间',
    `delivery_time`    STRING   COMMENT '发货时间',
    `receive_time`     STRING   COMMENT '收货时间',
    `receiver_name`    STRING   COMMENT '收货人',
    `receiver_phone`   STRING   COMMENT '收货电话',
    `receiver_address` STRING   COMMENT '收货地址',
    `order_remark`     STRING   COMMENT '订单备注',
    `create_time`      STRING   COMMENT '创建时间',
    `update_time`      STRING   COMMENT '更新时间'
)
PARTITIONED BY (`dt` STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;