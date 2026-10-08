# 修改为自己的jdk安装目录
export JAVA_HOME=${JAVA_HOME:-/opt/jdk}

# 修改MySQL配置
export DATABASE=${DATABASE:-mysql}
export SPRING_PROFILES_ACTIVE=${DATABASE}
export SPRING_DATASOURCE_URL="jdbc:mysql://localhost:3306/dolphinscheduler?useUnicode=true&characterEncoding=UTF-8&useSSL=false"
export SPRING_DATASOURCE_USERNAME="root"
export SPRING_DATASOURCE_PASSWORD="123456"

# DolphinScheduler服务相关配置
export SPRING_CACHE_TYPE=${SPRING_CACHE_TYPE:-none}
export SPRING_JACKSON_TIME_ZONE=${SPRING_JACKSON_TIME_ZONE:-GMT+8}
export MASTER_FETCH_COMMAND_NUM=${MASTER_FETCH_COMMAND_NUM:-10}

# 注册中心配置，修改为自己的zookeeper监听地址
export REGISTRY_TYPE=${REGISTRY_TYPE:-zookeeper}
export REGISTRY_ZOOKEEPER_CONNECT_STRING=${REGISTRY_ZOOKEEPER_CONNECT_STRING:-localhost:2181}

# 这些环境变量根据自己的需要更改，没有保持默认即口
# Tasks related configurations, need to change the configuration if you use the related tasks.
# export HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop3}
# export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/opt/hadoop3/etc/hadoop}
# export SPARK_HOME1=${SPARK_HOME1:-/opt/spark1}
# export SPARK_HOME2=${SPARK_HOME2:-/opt/spark2}
# export PYTHON_HOME=${PYTHON_HOME:- /usr/bin}
# export HIVE_HOME=${HIVE_HOME:-/opt/hive4}
# export FLINK_HOME=${FLINK_HOME:-/opt/flink}
# export DATAX_HOME=${DATAX_HOME:-/opt/datax}
# export PATH=$HADOOP_HOME/bin:$SPARK_HOME1/bin:$SPARK_HOME2/bin:$PYTHON_HOME/bin:$JAVA_HOME/bin:$HIVE_HOME/bin:$FLINK_HOME/bin:$DATAX_HOME/bin:$PATH
