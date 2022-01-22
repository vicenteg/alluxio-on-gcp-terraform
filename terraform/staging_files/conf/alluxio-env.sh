# File: alluxio-env.sh
#

# Alluxio Master Nodes:
export ALLUXIO_MASTER_JAVA_OPTS+=" -Xms64g -Xmx64g -XX:+UseConcMarkSweepGC -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseParNewGC -Xloggc:/opt/alluxio/logs/jvm_gc_master.log"

# Alluxio Worker Nodes:
export ALLUXIO_WORKER_JAVA_OPTS+=" -Xms24g -Xmx24g -XX:MaxDirectMemorySize=12g -XX:+UseConcMarkSweepGC -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseParNewGC -Xloggc:/opt/alluxio/logs/jvm_gc_worker.log"

# end of file

