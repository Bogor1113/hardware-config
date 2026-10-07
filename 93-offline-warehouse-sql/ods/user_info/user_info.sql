create database  if not exists  ods;



drop  table  if exists  ods.ods_user_info;


create table if not exists ods.ods_user_info
    (
        `user_id`          bigint COMMENT '用户ID'                   ,
        `username`         string COMMENT '用户名'                    ,
        `password`         string COMMENT '密码(MD5加密)'              ,
        `real_name`        string COMMENT '真实姓名'                   ,
        `gender`           tinyint COMMENT '性别：0未知 1男 2女'          ,
        `age`              int COMMENT '年龄'                        ,
        `phone`            string COMMENT '手机号'                    ,
        `email`            string COMMENT '邮箱'                     ,
        `city`             string COMMENT '城市'                     ,
        `province`         string COMMENT '省份'                     ,
        `address`          string COMMENT '详细地址'                   ,
        `register_date`    string COMMENT '注册日期'                   ,
        `register_channel` string COMMENT '注册渠道：APP/PC/MiniProgram',
        `user_level`       tinyint COMMENT '用户等级：1普通 2银卡 3金卡 4钻石'  ,
        `status`           tinyint COMMENT '状态：0禁用 1正常'            ,
        `create_time`      string COMMENT '创建时间'                   ,
        `update_time`      string COMMENT '更新时间'
    )
row format delimited fields terminated by '\t' stored as TEXTfile;