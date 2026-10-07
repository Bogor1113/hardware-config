create database  if not exists  ods;



drop  table  if exists  ods.ods_brand_info;


create table if not exists ods.ods_brand_info
    (
        `brand_id`     int COMMENT '品牌ID'                 ,
        `brand_name`   string COMMENT '品牌名称'             ,
        `brand_en`     string COMMENT '英文名'               ,
        `country`      string COMMENT '所属国家/地区'        ,
        `create_time`  string COMMENT '创建时间'
    )
row format delimited fields terminated by '\t' stored as TEXTfile;
