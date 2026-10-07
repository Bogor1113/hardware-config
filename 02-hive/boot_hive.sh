#!/bin/bash
export PATH=/opt/hadoop3/bin:/opt/hive3/bin:/opt/jdk/bin:$PATH
cd /opt/hive3
nohup bin/hive --service metastore > /opt/hive3/logs/metastore.log 2>&1 &
disown
sleep 10
nohup bin/hive --service hiveserver2 > /opt/hive3/logs/hs2.log 2>&1 &
disown
echo LAUNCHED
