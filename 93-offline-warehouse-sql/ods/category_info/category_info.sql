create database  if not exists  ods;



drop  table  if exists  ods.ods_category_info;


create table if not exists ods.ods_category_info
    (
        `category_id`     int COMMENT '分类ID'                      ,
        `category_name`   string COMMENT '分类名称'                  ,
        `parent_id`       int COMMENT '父分类ID'                    ,
        `category_level`  tinyint COMMENT '分类层级：1一级 2二级 3三级'  ,
        `sort_order`      int COMMENT '排序'                        ,
        `status`          tinyint COMMENT '状态：0禁用 1正常'         ,
        `create_time`     string COMMENT '创建时间'                   
    )
row format delimited fields terminated by '\t' stored as TEXTfile;
