#!/bin/bash

if [ $# -ne 1 ];then
   echo "怎么洗给一个参数"
   exit 1
fi  

yesterday=$(date  -d '1 days ago' "+%Y-%m-%d")   # 定义昨天
project_path="/home/cloud_ecommerce_project/dwd"

all(){

    partition=$(hive -e  "show partitions  ods.ods_order_info")
    echo ${partition}
    for par  in   ${partition};do
    if [ "${par}" != "partition" ];then
        echo "======正在清洗 ${par} 分区数据=========="
        hive  --hiveconf  ${par}   -f ${project_path}/dwd_user_order_clean.sql
    fi
    done
}

par(){
    hive  --hiveconf  dt=${yesterday}   -f ${project_path}/dwd_user_order_clean.sql

}

case  $1  in 
all)
    all
 ;;
par)
   par
;;
*)
  echo "参数错误"
;;
esac