# File: alluxio-env.sh
#

export ALLUXIO_MASTER_JAVA_OPTS+=" -XX:InitialHeapSize=64g -XX:MaxHeapSize=64g -XX:+UseConcMarkSweepGC -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseParNewGC -Xloggc:/opt/alluxio/logs/jvm_gc_master.log"

export ALLUXIO_WORKER_JAVA_OPTS+=" -XX:InitialHeapSize=24g -XX:MaxHeapSize=24g -XX:MaxDirectMemorySize=12g -XX:+UseConcMarkSweepGC -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseParNewGC -Xloggc:/opt/alluxio/logs/jvm_gc_worker.log"

# end of file

