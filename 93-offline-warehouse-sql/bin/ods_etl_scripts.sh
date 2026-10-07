#!/bin/bash
# 你要给2个参数 第一个的抽取哪个表  第二个是怎么抽 all   increment   first
if  [ $# -ne  2 ];then
    echo "参数个数不对，必须是2个"
    exit 1
fi

# 初始值设定
table_name=$1    # 定义表的名字
extract_type=$2  # 定义抽取的方式
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

# 定义函数
all(){
    echo "======================全量抽取 ${table_name}=================================="   >>  ${logfile}
    hive  -f    ${project_path}/${table_name}/${table_name}.sql               >>  ${logfile}

    echo "======================datax开始抽取 ${table_name}=============================="  >>  ${logfile}
    python3  /opt/datax/bin/datax.py    ${project_path}/${table_name}/${table_name}.json  >>  ${logfile}

    echo "=======================全量抽数 ${table_name}完成=============================="  >>  ${logfile}
}


# 定义函数
first(){
    echo "======================首次抽取 ${table_name}=================================="   >>  ${logfile}
    hive  -f    ${project_path}/${table_name}/${table_name}.sql               >>  ${logfile}
    # 查业务数据库最小日期
    result=$(mysql -h${mysqlhost}  -P${mysqlport}  -u${mysqluser}  -p${mysqlpwd}  -e  "select  date(min(create_time)) as mindt from ${mysqldatabase}.${table_name}")
   
    mindt=`echo  ${result}  |awk  '{print $2}'`
     echo "=============业务数据库最小日期：${mindt}================== " >>  ${logfile}
    while  [ "${mindt}"  != "${today}" ]:
        do
           hadoop  fs  -mkdir  -p   ${hdfs_path}/ods_${table_name}/dt=${mindt}                     >>  ${logfile}
           echo "======================datax开始抽取 ${table_name}的分区${mindt}=============================="  >>  ${logfile}
           python3  /opt/datax/bin/datax.py  -p"-Ddt=${mindt}"  ${project_path}/${table_name}/${table_name}.json   >>  ${logfile}

           mindt=$(date -d "$mindt 1 day "  "+%Y-%m-%d" )
        done
    echo  "======================修复 ${table_name} 分区======================">>  ${logfile}
    hive  -e   "msck repair   table   ods.ods_${table_name}"   >>  ${logfile}
}


# 函数  t+1 只抽昨天的数据
increment(){
    echo "======================t+1抽取 ${table_name}=================================="   >>  ${logfile}
    # 加固我们的代码 更稳定,不知道昨天的分区是否存在，先干掉再说
    hive  -e  "alter table   ods.ods_${table_name}  drop  partition (dt='${yesterday}');"  >>  ${logfile}
    # 在hdfs创建一个路径 用来存等下抽取过来的数据
    hadoop  fs  -mkdir  -p   ${hdfs_path}/ods_${table_name}/dt=${yesterday}                     >>  ${logfile}
    echo "======================datax开始抽取 ${table_name}的分区${yesterday}=============================="  >>  ${logfile}
    python3  /opt/datax/bin/datax.py  -p"-Ddt=${yesterday}"  ${project_path}/${table_name}/${table_name}.json   >>  ${logfile}

    echo  "======================修复 ${table_name} 分区======================">>  ${logfile}
    hive  -e   "msck repair   table   ods.ods_${table_name}"   >>  ${logfile}

}


# 分支语句 
case $extract_type  in 
    all)
        all   # 调用上面的函数
    ;;

    first)
        first
    ;;
    
    increment)
        increment
    ;;
    *)
        echo "抽取方式错误"
    ;;
esac