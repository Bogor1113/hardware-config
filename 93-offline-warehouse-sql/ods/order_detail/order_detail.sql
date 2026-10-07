
create database  if not exists  ods;



drop  table  if exists  ods.ods_order_detail;

CREATE TABLE IF NOT EXISTS ods.ods_order_detail
(
    `detail_id`        BIGINT        COMMENT '详情ID',
    `order_id`         BIGINT        COMMENT '订单ID',
    `product_id`       BIGINT        COMMENT '商品ID',
    `product_price`    DECIMAL(10,2) COMMENT '商品单价',
    `product_quantity` INT           COMMENT '购买数量',
    `total_amount`     DECIMAL(12,2) COMMENT '商品总价',
    `create_time`      STRING        COMMENT '创建时间'
)
PARTITIONED BY (`dt` STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;
