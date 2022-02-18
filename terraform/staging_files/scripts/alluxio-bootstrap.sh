#!/usr/bin/env bash
#
# The Alluxio Open Foundation licenses this work under the Apache License, version 2.0
# (the "License"). You may not use this work except in compliance with the License, which is
# available at www.apache.org/licenses/LICENSE-2.0
#
# This software is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied, as more fully set forth in the License.
#
# See the NOTICE file distributed with this work for information regarding copyright ownership.
#

set -eux

####################
# Global constants #
####################
readonly MASTER_FQDN="$(/usr/share/google/get_metadata_value attributes/dataproc-master)"
readonly ROLE="$(/usr/share/google/get_metadata_value attributes/dataproc-role)"
readonly ALLUXIO_DOWNLOAD_PATH="$(/usr/share/google/get_metadata_value attributes/alluxio_download_path || true)"
readonly ALLUXIO_LICENSE_BASE64="$(/usr/share/google/get_metadata_value attributes/alluxio_license_base64 || true)"
readonly SPARK_HOME="${SPARK_HOME:-"/usr/lib/spark"}"
readonly HIVE_HOME="${HIVE_HOME:-"/usr/lib/hive"}"
readonly HADOOP_HOME="${HADOOP_HOME:-"/usr/lib/hadoop"}"
readonly PRESTO_HOME="$(/usr/share/google/get_metadata_value attributes/alluxio_presto_home || echo "/usr/lib/presto")"
readonly ALLUXIO_VERSION="2.7.0"
readonly ALLUXIO_DOWNLOAD_URL="https://downloads.alluxio.io/downloads/files/${ALLUXIO_VERSION}/alluxio-${ALLUXIO_VERSION}-bin.tar.gz"
readonly ALLUXIO_HOME="/opt/alluxio"
readonly ALLUXIO_SITE_PROPERTIES="${ALLUXIO_HOME}/conf/alluxio-site.properties"
readonly ALLUXIO_ENV_SH="${ALLUXIO_HOME}/conf/alluxio-env.sh"

####################
# Helper functions #
####################
# Appends a property KV pair to the alluxio-site.properties file
#
# Args:
#   $1: property
#   $2: value
append_alluxio_property() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function append_alluxio_property, expecting 2"
    exit 2
  fi
  local property="$1"
  local value="$2"

  if grep -qe "^\s*${property}=" ${ALLUXIO_SITE_PROPERTIES} 2> /dev/null; then
    echo "Property ${property} already exists in ${ALLUXIO_SITE_PROPERTIES}" >&2
  else
    doas alluxio "echo '${property}=${value}' >> ${ALLUXIO_SITE_PROPERTIES}"
  fi
}

# Gets a value from a KV pair in the alluxio-site.properties file
#
# Args:
#   $1: property
get_alluxio_property() {
  if [[ "$#" -ne "1" ]]; then
    echo "Incorrect number of arguments passed into function get_alluxio_property, expecting 1"
    exit 2
  fi
  local property="$1"

  grep -e "^\s*${property}=" ${ALLUXIO_SITE_PROPERTIES} | cut -d "=" -f2
}

# Run a command as a specific user
# Assumes the provided user already exists on the system and user running script has sudo access
#
# Args:
#   $1: user
#   $2: cmd
doas() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function doas, expecting 2"
    exit 2
  fi
  local user="$1"
  local cmd="$2"

  sudo runuser -l "${user}" -c "${cmd}"
}

# Downloads a file to the local machine into the cwd
# For the given scheme, uses the corresponding tool to download:
# s3://   -> aws s3 cp
# gs://   -> gsutil cp
# default -> wget
#
# Args:
#   $1: uri - S3, GS, or HTTP(S) URI to download from
download_file() {
  if [[ "$#" -ne "1" ]]; then
    echo "Incorrect number of arguments passed into function download_file, expecting 1"
    exit 2
  fi
  local uri="$1"

  if [[ "${uri}" == s3://* ]]; then
    aws s3 cp "${uri}" ./
  elif [[ "${uri}" == gs://* ]]; then
    gsutil cp "${uri}" ./
  else
    # TODO Add metadata header tag to the wget for filtering out in download metrics.
    wget "${uri}"
  fi
}

# Calculates the default memory size as 1/3 of the total system memory
# Echo's the result to stdout. To store the return value in a variable use
# val=$(get_default_mem_size)
get_default_mem_size() {
  local -r mem_div=3
  phy_total=$(free -m | grep -oP '\d+' | head -n1)
  mem_size=$(( phy_total / mem_div ))
  echo "${mem_size}MB"
}

####################
# Task functions #
####################

# Configure client applications
expose_alluxio_client_jar() {
  sudo mkdir -p "${SPARK_HOME}/jars/"
  sudo ln -s "${ALLUXIO_HOME}/client/alluxio-client.jar" "${SPARK_HOME}/jars/alluxio-client.jar"
  sudo mkdir -p "${HIVE_HOME}/lib/"
  sudo ln -s "${ALLUXIO_HOME}/client/alluxio-client.jar" "${HIVE_HOME}/lib/alluxio-client.jar"
  sudo mkdir -p "${HADOOP_HOME}/lib/"
  sudo ln -s "${ALLUXIO_HOME}/client/alluxio-client.jar" "${HADOOP_HOME}/lib/alluxio-client.jar"
  if [[ "${ROLE}" == "Master" ]]; then
    systemctl restart hive-metastore hive-server2
  fi
  sudo mkdir -p "${PRESTO_HOME}/plugin/hive-hadoop2/"
  sudo ln -s "${ALLUXIO_HOME}/client/alluxio-client.jar" "${PRESTO_HOME}/plugin/hive-hadoop2/alluxio-client.jar"
  systemctl restart presto || echo "Presto service cannot be restarted"
}

configure_alluxio_systemd_services() {
  if [[ "${ROLE}" == "Master" ]]; then
    # The master role runs 3 daemons: AlluxioMaster and AlluxioJobMaster and HubManager
    # Service for AlluxioMaster JVM
    cat >"/etc/systemd/system/alluxio-master.service" <<- EOF
[Unit]
Description=Alluxio Master
After=default.target
[Service]
Type=simple
User=alluxio
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process master -c
Restart=no
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable alluxio-master

    # Service for AlluxioJobMaster JVM
    cat >"/etc/systemd/system/alluxio-job-master.service" <<- EOF
[Unit]
Description=Alluxio Job Master
After=default.target
[Service]
Type=simple
User=alluxio
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process job_master -c
Restart=no
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable alluxio-job-master

    # Service for HubManager JVM
    cat >"/etc/systemd/system/hub-manager.service" <<- EOF
[Unit]
Description=Alluxio Hub Manager
After=default.target
[Service]
Type=simple
User=alluxio
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process hub_manager -c
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
    #systemctl enable hub-manager
  else
    # The worker role runs 2 daemons: AlluxioWorker and AlluxioJobWorker
    # Service for AlluxioWorker JVM
    cat >"/etc/systemd/system/alluxio-worker.service" <<- EOF
[Unit]
Description=Alluxio Worker
After=default.target
[Service]
Type=simple
User=alluxio
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process worker -c
Restart=no
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable alluxio-worker
    # Service for AlluxioJobWorker JVM
    cat >"/etc/systemd/system/alluxio-job-worker.service" <<- EOF
[Unit]
Description=Alluxio Job Worker
After=default.target
[Service]
Type=simple
User=alluxio
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process job_worker -c
Restart=no
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable alluxio-job-worker
  fi

  # Service for AlluxioProxy JVM (on both masters and worers)
  cat >"/etc/systemd/system/alluxio-proxy.service" <<- EOF
[Unit]
Description=Alluxio Proxy
After=default.target
[Service]
Type=simple
User=alluxio
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process proxy -c
Restart=no
[Install]
WantedBy=multi-user.target
EOF
  systemctl enable alluxio-proxy

    # Launch hub agent on all nodes
    # Service for HubAgent JVM
    cat >"/etc/systemd/system/hub-agent.service" <<- EOF
[Unit]
Description=Alluxio Hub Agent
After=default.target
[Service]
Type=simple
User=root
WorkingDirectory=${ALLUXIO_HOME}
ExecStart=${ALLUXIO_HOME}/bin/launch-process hub_agent -c
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
    #systemctl enable hub-agent
}

# Configure SSD if necessary and relevant alluxio-site.properties
configure_alluxio_storage() {
  local -r mem_size=$(get_default_mem_size)
  local -r ssd_capacity_usage=$(/usr/share/google/get_metadata_value attributes/alluxio_ssd_capacity_usage || true)
  local use_mem="true"

  if [[ "${ssd_capacity_usage}" ]]; then
    if [[ "${ssd_capacity_usage}" -lt 1 || "${ssd_capacity_usage}" -gt 100 ]]; then
      echo "The percent usage of ssd storage usage must be between 1 and 100"
      exit 1
    fi

    local paths=""
    local quotas=""
    local medium_type=""
    # Retrieve paths of ssd devices who are mounted at /mnt*
    # in the format of "<dev name> <capacity> <mount path>"
    # The block size parameter (-B) is in MB (1024 * 1024)
    local -r mount_points="$(lsblk -d -o name,rota | awk 'NR>1' |
      while read -r ROW;
      do
        dd=$(echo "$ROW" | awk '{print $2}');
        if [ "${dd}" -eq 0 ]; then
          df -B 1048576 | grep "$(echo "$ROW" | awk '{print $1}')" | grep "/mnt" | awk '{print $1, $4, $6}';
        fi;
      done
    )"
    set +e
    # read returns 1 unless EOF is reached, but we specify -d '' which means always read until EOF
    IFS=$'\n' read -d '' -ra mounts <<< "${mount_points}"
    set -e
    # attempt to configure ssd, otherwise fallback to MEM
    if [[ "${#mounts[@]}" -gt 0 ]]; then
      for mount_point in "${mounts[@]}"; do
    	  local path_cap
    	  local mnt_path
    	  local quota_p
    	  path_cap="$(echo "${mount_point}" | awk '{print $2}')"
    	  mnt_path="$(echo "${mount_point}" | awk '{print $3}')"
    	  quota_p=$((path_cap * ssd_capacity_usage / 100))
    	  # if alluxio doesn't have permissions to write to this directory it will fail
    	  mnt_path+="/alluxio"
    	  sudo mkdir -p "${mnt_path}"
    	  sudo chown -R alluxio:alluxio "${mnt_path}"
    	  sudo chmod 777 "${mnt_path}"
    	  paths+="${mnt_path},"
    	  quotas+="${quota_p}MB,"
    	  medium_type+="SSD,"
      done
      paths="${paths::-1}"
      quotas="${quotas::-1}"
      medium_type="${medium_type::-1}"

      use_mem=""
      append_alluxio_property alluxio.worker.tieredstore.level0.alias "SSD"
      append_alluxio_property alluxio.worker.tieredstore.level0.dirs.mediumtype "${medium_type}"
      append_alluxio_property alluxio.worker.tieredstore.level0.dirs.path "${paths}"
      append_alluxio_property alluxio.worker.tieredstore.level0.dirs.quota "${quotas}"
    fi
  fi

  if [[ "${use_mem}" ]]; then
    append_alluxio_property alluxio.worker.ramdisk.size "${mem_size}"
    append_alluxio_property alluxio.worker.tieredstore.level0.alias "MEM"
    append_alluxio_property alluxio.worker.tieredstore.level0.dirs.path "/mnt/ramdisk"
  fi
}

# Download the Alluxio tarball and untar to ALLUXIO_HOME
bootstrap_alluxio() {
  # Download the Alluxio tarball
  mkdir ${ALLUXIO_HOME}
  local download_url="${ALLUXIO_DOWNLOAD_URL}"
  if [ -n "${ALLUXIO_DOWNLOAD_PATH}" ]; then
    download_url=${ALLUXIO_DOWNLOAD_PATH}
  fi
  download_file "${download_url}"
  local tarball_name=${download_url##*/}
  tar -zxf "${tarball_name}" -C ${ALLUXIO_HOME} --strip-components 1
  ln -s ${ALLUXIO_HOME}/client/*client.jar ${ALLUXIO_HOME}/client/alluxio-client.jar

  # Download files to /opt/alluxio/conf
  local -r download_files_list=$(/usr/share/google/get_metadata_value attributes/alluxio_download_files_list || true)
  local download_delimiter=";"
  IFS="${download_delimiter}" read -ra files_to_be_downloaded <<< "${download_files_list}"
  if [ "${#files_to_be_downloaded[@]}" -gt "0" ]; then
    local filename
    for file in "${files_to_be_downloaded[@]}"; do
      filename="$(basename "${file}")"
      download_file "${file}"
      mv "${filename}" "${ALLUXIO_HOME}/conf/${filename}"
    done
  fi

  # add alluxio user
  id -u alluxio &>/dev/null || sudo useradd -m alluxio
  # add test users
  id -u user1 &>/dev/null || sudo useradd --no-create-home --home-dir /tmp user1
  id -u user2 &>/dev/null || sudo useradd --no-create-home --home-dir /tmp user2

  # dataproc by default will install alluxio as user kafka
  # change the user and group to alluxio
  sudo chown -R alluxio:alluxio "${ALLUXIO_HOME}"
  # Allow bash/all users to execute alluxio command
  echo -e '#!/bin/bash\nexec /opt/alluxio/bin/alluxio $@' | sudo tee /usr/bin/alluxio
  sudo chmod 755 /usr/bin/alluxio

  configure_alluxio_systemd_services
  expose_alluxio_client_jar

  # Optionally configure license
  if [ -n "${ALLUXIO_LICENSE_BASE64}" ]; then
    echo "${ALLUXIO_LICENSE_BASE64}" | base64 -d > ${ALLUXIO_HOME}/license.json
  fi

  # Create "alluxio_ufs" directory and some test user dirs in Google Cloud Storage bucket
  touch /tmp/ignore.tmp
  gsutil cp /tmp/ignore.tmp "gs://${gs_ufs_bucket}/alluxio_ufs"
  #gsutil cp /tmp/ignore.tmp "gs://${gs_ufs_bucket}/alluxio_ufs/user/alluxio/"
  #gsutil cp /tmp/ignore.tmp "gs://${gs_ufs_bucket}/alluxio_ufs/user/user1/"
  #gsutil cp /tmp/ignore.tmp "gs://${gs_ufs_bucket}/alluxio_ufs/user/user2/"
  rm /tmp/ignore.tmp

}

configure_alluxio() {

  # Copy the alluxio-site.properties file from the google storage bucket
  local -r gs_conf_folder=$(/usr/share/google/get_metadata_value attributes/alluxio_gs_conf_folder || true)
  doas alluxio "gsutil cp ${gs_conf_folder}/alluxio-site.properties ${ALLUXIO_SITE_PROPERTIES}"
  doas alluxio "gsutil cp ${gs_conf_folder}/alluxio-env.sh ${ALLUXIO_ENV_SH}"

  # Configure alluxio-site.properties file
  sudo sed -i "s/ALLUXIO_MASTER/${MASTER_FQDN}/g" "${ALLUXIO_SITE_PROPERTIES}"
  sudo sed -i "s/GS_UFS_BUCKET/${gs_ufs_bucket}/g" "${ALLUXIO_SITE_PROPERTIES}"

  # Copy the HDFS xml files
  doas alluxio "gsutil cp ${gs_conf_folder}/core-site.xml $ALLUXIO_HOME/conf/core-site.xml"
  doas alluxio "gsutil cp ${gs_conf_folder}/hdfs-site.xml $ALLUXIO_HOME/conf/hdfs-site.xml"

  # TODO: Copy the kerberos keytab files 

}

# Start the Alluxio server process
start_alluxio() {
  if [[ "${ROLE}" == "Master" ]]; then
    doas alluxio "${ALLUXIO_HOME}/bin/alluxio formatJournal"
    systemctl restart alluxio-master alluxio-job-master alluxio-proxy
    #systemctl restart hub-manager hub-agent

    #local -r sync_list=$(/usr/share/google/get_metadata_value attributes/alluxio_sync_list || true)
    #local path_delimiter=";"
    #if [[ "${sync_list}" ]]; then
    #  IFS="${path_delimiter}" read -ra paths <<< "${sync_list}"
    #  for path in "${paths[@]}"; do
    #    doas alluxio "${ALLUXIO_HOME}/bin/alluxio fs startSync ${path}"
    #  done
    #fi

  else
    if [[ $(get_alluxio_property alluxio.worker.tieredstore.level0.alias) == "MEM" ]]; then
      ${ALLUXIO_HOME}/bin/alluxio-mount.sh SudoMount local
    fi
    doas alluxio "${ALLUXIO_HOME}/bin/alluxio formatWorker"
    systemctl restart alluxio-worker alluxio-job-worker alluxio-proxy
    #systemctl restart hub-agent
  fi
}

# chmod on a alluxio directory - Usage: alluxio_chmod 777 /user
alluxio_chmod() {

  changed_indicator_file=/tmp/alluxio_dirs_perms_changed
  for i in {1..10}; 
  do 
    doas alluxio "alluxio fs ls $2"

    if [ "$?" == 0 ]; then
      doas alluxio "alluxio fs chmod $1 $2"
      if [ "$?" == 0 ]; then
        touch $changed_indicator_file
        echo " Permissions successfully changed to $1 on Alluxio dir: $2"
      fi
      break;
    fi
    # wait for Alluxio to see GCS understore
    sleep 10
  done

  if [ -f $changed_indicator_file ]; then
    echo " Error: Permissions NOT successfully changed to $1 on Alluxio dir: $2"
  fi
  rm $changed_indicator_file
}

# chown on a alluxio directory - Usage: alluxio_chown user1 /user/user1
alluxio_chown() {

  changed_indicator_file=/tmp/alluxio_dirs_owner_changed
  for i in {1..10}; 
  do 
    doas alluxio "alluxio fs ls $2"

    if [ "$?" == 0 ]; then
      doas alluxio "alluxio fs chown -R $1 $2"
      if [ "$?" == 0 ]; then
        touch $changed_indicator_file
        echo " Owner successfully changed to $1 on Alluxio dir: $2"
      fi
      break;
    fi
    # wait for Alluxio to see GCS understore
    sleep 10
  done

  if [ -f $changed_indicator_file ]; then
    echo " Error: Owner NOT successfully changed to $1 on Alluxio dir: $2"
  fi
  rm $changed_indicator_file
}

# Make an alluxio directory - Usage: make_alluxio_dir /user/user1
alluxio_create_dir() {

  changed_indicator_file=/tmp/alluxio_dirs_created
  for i in {1..10}; 
  do 
    doas alluxio "alluxio fs ls /"

    if [ "$?" == 0 ]; then
      doas alluxio "alluxio fs mkdir $1"
      if [ "$?" == 0 ]; then
        touch $changed_indicator_file
        echo " Successfully created $1 dir on Alluxio"
      fi
      break;
    fi
    # wait for Alluxio to see GCS understore
    sleep 10
  done

  if [ -f $changed_indicator_file ]; then
    echo " Error: unsuccessful in creating $1 dir on Alluxio"
  fi
  rm $changed_indicator_file
}

#################
# Main function #
#################
main() {
  # Stop and disable presto service (not needed for this implementation)
  #systemctl stop presto 
  #systemctl disable presto 

  echo "Alluxio version: ${ALLUXIO_VERSION}"
  local -r gs_ufs_bucket=$(/usr/share/google/get_metadata_value attributes/alluxio_gs_ufs_bucket || true)

  bootstrap_alluxio
  configure_alluxio
  start_alluxio

  if [[ "${ROLE}" == "Master" ]]; then
    doas alluxio "alluxio fs copyFromLocal /etc/motd /"
    alluxio_create_dir /tmp
    alluxio_chmod 777 /tmp
    alluxio_create_dir /user
    alluxio_chmod 777 /user
    alluxio_create_dir /user/user1
    alluxio_chown user1 /user/user1
    alluxio_create_dir /user/user2
    alluxio_chown user2 /user/user2
    doas alluxio "alluxio fs rm /motd"
  fi
}

main "$@"
