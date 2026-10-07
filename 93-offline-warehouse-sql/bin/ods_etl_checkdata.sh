#!/bin/bash


today=$(date "+%Y-%m-%d")  # 计算今天日期
yesterday=$(date  -d '1 days ago' "+%Y-%m-%d")   # 定义昨天
project_path='/home/cloud_ecommerce_project/ods'  # 定义我的项目路径
hdfs_path='/hive3/warehouse/ods.db'               # 定义我的hdfs路径
logfile=${project_path}/../logs/${today}.log         # 定义日志文件目录
mysqlhost='192.168.110.131'
mysqlport='3306'
mysqluser='bigdata'
mysqlpwd='bigdata'
mysqldatabase='cloud_ecommerce'

# 写sql计算
sql="
select   count(user_id)     as user_id_ct   from  ods.ods_user_info;
select   count(brand_id)    as user_id_ct   from  ods.ods_brand_info;
select   count(product_id)  as user_id_ct   from  ods.ods_product_info;
select   count(category_id) as user_id_ct   from  ods.ods_category_info;

select   count(order_id)    as user_id_ct   from  ods.ods_order_info    where  dt='${yesterday}';
select   count(detail_id)   as user_id_ct   from  ods.ods_order_detail  where  dt='${yesterday}';
select   count(pay_id)      as user_id_ct   from  ods.ods_payment_info  where  dt='${yesterday}';
"

# 把执行结果输出到文件里面

hive  -e "${sql}"   > ${project_path}/result_hive.txt


# 业务数据库的数据呢
sql2="
select   count(user_id)     as user_id_ct   from  ${mysqldatabase}.user_info;
select   count(brand_id)    as user_id_ct   from  ${mysqldatabase}.brand_info;
select   count(product_id)  as user_id_ct   from  ${mysqldatabase}.product_info;
select   count(category_id) as user_id_ct   from  ${mysqldatabase}.category_info;

select   count(order_id)    as user_id_ct   from  ${mysqldatabase}.order_info    where  date(create_time)='${yesterday}';
select   count(detail_id)   as user_id_ct   from  ${mysqldatabase}.order_detail  where  date(create_time)='${yesterday}';
select   count(pay_id)      as user_id_ct   from  ${mysqldatabase}.payment_info  where  date(create_time)='${yesterday}';
"

mysql -h${mysqlhost}  -P${mysqlport}  -u${mysqluser}  -p${mysqlpwd}  -e "${sql2}"    > ${project_path}/result_mysql.txt


# 对比
result=`diff -q   ${project_path}/result_hive.txt     ${project_path}/result_mysql.txt  > /dev/null && echo "相同" || echo "不同"`

if [  "${result}"  = "相同" ];then
    echo "数据校验通过"
    exit 0   # 返回码，linux里面总共0-127；除了0以外，剩下的都是错误码
else
    echo  "error,数据校验不通过"
    exit 1
fi