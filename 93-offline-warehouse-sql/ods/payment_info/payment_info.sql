
create database  if not exists  ods;



drop  table  if exists  ods.ods_payment_info;

CREATE TABLE IF NOT EXISTS ods.ods_payment_info
(
    `pay_id`         BIGINT        COMMENT '支付ID',
    `order_id`       BIGINT        COMMENT '订单ID（与order_info.order_id强外键，DWD层通过它JOIN）',
    `pay_amount`     DECIMAL(12,2) COMMENT '支付金额',
    `payment_method` STRING        COMMENT '支付方式',
    `payment_status` TINYINT       COMMENT '支付状态：0待支付 1支付成功 2支付失败 3已退款',
    `transaction_id` STRING        COMMENT '第三方交易流水号',
    `pay_time`       STRING        COMMENT '支付完成时间',
    `create_time`    STRING        COMMENT '创建时间',
    `update_time`    STRING        COMMENT '更新时间'
)
PARTITIONED BY (`dt` STRING COMMENT '分区日期')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;
