create database  if not exists  dim;



drop  table  if exists  dim.dim_code_value;


create table if not exists dim.dim_code_value
    (
        `code_id`          int COMMENT '码值ID'                                ,
        `code_group`       string COMMENT '码组编码（如 gender / order_status）' ,
        `code_group_name`  string COMMENT '码组中文名（如 性别 / 订单状态）'     ,
        `code_value`       string COMMENT '码值（数字或字符串）'                ,
        `code_label`       string COMMENT '码值含义（如 1=男 / 待付款）'        ,
        `sort_order`       int COMMENT '排序（用于下拉选项）'                  ,
        `status`           tinyint COMMENT '0=停用 1=启用'                     ,
        `create_time`      string COMMENT '创建时间'
    )
row format delimited fields terminated by '\t' stored as TEXTfile;
