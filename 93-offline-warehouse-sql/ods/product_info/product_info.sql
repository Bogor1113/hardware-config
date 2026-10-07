create database  if not exists  ods;



drop  table  if exists  ods.ods_product_info;


create table if not exists ods.ods_product_info
    (
        `product_id`      bigint COMMENT '商品ID'                     ,
        `product_name`    string COMMENT '商品名称'                   ,
        `category_id`     int COMMENT '分类ID'                       ,
        `brand_id`        int COMMENT '品牌ID'                       ,
        `product_price`   decimal(10,2) COMMENT '商品价格'            ,
        `market_price`    decimal(10,2) COMMENT '市场价'              ,
        `cost_price`      decimal(10,2) COMMENT '成本价'              ,
        `stock`           int COMMENT '库存'                         ,
        `sales`           int COMMENT '销量'                         ,
        `product_weight`  decimal(8,2) COMMENT '重量(g)'              ,
        `product_desc`    string COMMENT '商品描述'                   ,
        `main_image`      string COMMENT '主图'                       ,
        `status`          tinyint COMMENT '状态：0下架 1上架'          ,
        `create_time`     string COMMENT '创建时间'                   ,
        `update_time`     string COMMENT '更新时间'
    )
row format delimited fields terminated by '\t' stored as TEXTfile;
