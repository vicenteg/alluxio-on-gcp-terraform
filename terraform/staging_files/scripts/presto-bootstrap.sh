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
readonly HADOOP_CONF="/etc/hadoop/conf"
readonly PRESTO_CONF="/etc/presto/conf"
readonly PRESTO_JVM_CONFIG_FILE="${PRESTO_CONF}/jvm.config"
readonly PRESTO_HIVE_CATALOG="${PRESTO_CONF}/catalog/hive.properties"
readonly PRESTO_ONPREM_CATALOG="${PRESTO_CONF}/catalog/onprem.properties"

####################
# Helper functions #
####################
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
    wget "${uri}"
  fi
}

# Appends or replaces a property KV pair to the alluxio-site.properties file
#
# Args:
#   $1: property
#   $2: value
set_presto_hive_property() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function set_alluxio_property, expecting 2"
    exit 2
  fi
  local property="$1"
  local value="$2"

  if grep -qe "^\s*${property}" ${PRESTO_HIVE_CATALOG} 2> /dev/null; then
    sed -i "s;${property}.*;${property}=${value};g" "${PRESTO_HIVE_CATALOG}"
    echo "Property ${property} already exists in ${PRESTO_HIVE_CATALOG} and is replaced with value ${value}" >&2
  else
    echo "${property}=${value}" | sudo tee -a "${PRESTO_HIVE_CATALOG}"
  fi
}

# Appends or replaces a property KV pair to the alluxio-site.properties file
#
# Args:
#   $1: property
#   $2: value
set_presto_onprem_property() {
  if [[ "$#" -ne "2" ]]; then
    echo "Incorrect number of arguments passed into function set_alluxio_property, expecting 2"
    exit 2
  fi
  local property="$1"
  local value="$2"

  if grep -qe "^\s*${property}" ${PRESTO_ONPREM_CATALOG} 2> /dev/null; then
    sed -i "s;${property}.*;${property}=${value};g" "${PRESTO_ONPREM_CATALOG}"
    echo "Property ${property} already exists in ${PRESTO_ONPREM_CATALOG} and is replaced with value ${value}" >&2
  else
    echo "${property}=${value}" | sudo tee -a "${PRESTO_ONPREM_CATALOG}"
  fi
}

#################
# Task function #
#################
configure_presto() {
  local hive_catalog_address=$(/usr/share/google/get_metadata_value attributes/presto_hive_catalog_address || true)
  if [[ -z  "${hive_catalog_address}" ]]; then
     hive_catalog_address="thrift://${MASTER_FQDN}:9083"
  fi

  # download files to ${PRESTO_CONF}/alluxioConf/
  mkdir -p "${PRESTO_CONF}/alluxioConf"
  local -r download_files_list=$(/usr/share/google/get_metadata_value attributes/presto_download_files_list || true)
  local download_delimiter=";"
  IFS="${download_delimiter}" read -ra files_to_be_downloaded <<< "${download_files_list}"
  if [ "${#files_to_be_downloaded[@]}" -gt "0" ]; then
    local filename
    for file in "${files_to_be_downloaded[@]}"; do
      filename="$(basename "${file}")"
      echo "downloading ${filename}"
      download_file "${file}"
      mv "${filename}" "${PRESTO_CONF}/alluxioConf/${filename}"
    done
  fi

  echo "Starting Presto configuration"
  # onprem catalog is created for hybrid use cases
  # onprem catalog may be configured with onprem hdfs/hive, alluxio shim based on user inputs
  # the original hive catalog is left untouch
  cp "${PRESTO_HIVE_CATALOG}" "${PRESTO_ONPREM_CATALOG}"
  set_presto_onprem_property hive.hdfs.impersonation.enabled "true"
  set_presto_onprem_property hive.metastore.uri "${hive_catalog_address}"
  set_presto_onprem_property hive.split-loader-concurrency "100"

  # core-site.xml and hdfs-site.xml downloaded from the file list will override the default one
  core_site_path="${PRESTO_CONF}/alluxioConf/core-site.xml"
  hdfs_site_path="${PRESTO_CONF}/alluxioConf/hdfs-site.xml"
  if [[ ! -f "${core_site_path}" ]]; then
    sudo cp "${HADOOP_CONF}/core-site.xml" "${core_site_path}"
  fi
  if [[ ! -f "${hdfs_site_path}" ]]; then
    sudo cp "${HADOOP_CONF}/hdfs-site.xml" "${hdfs_site_path}"
  fi
  hive_config_resources_key="hive.config.resources"
  hive_config_resources_value="${core_site_path},${hdfs_site_path}"
  set_presto_onprem_property "${hive_config_resources_key}" "${hive_config_resources_value}"
  # dataproc sets global hive.config.resources in jvm.config instead of catalog/hive.properties
  # move original value back to catalog/hive.properties
  # so that onprem.properties can be configured with new config resources
  original_hive_config_resources=$(cat ${PRESTO_JVM_CONFIG_FILE} | grep "${hive_config_resources_key}" | cut -d"=" -f2)
  set_presto_hive_property hive.config.resources "${original_hive_config_resources}"
  sed -i "/^-D${hive_config_resources_key}/d" "${PRESTO_JVM_CONFIG_FILE}"

  local -r configure_alluxio_shim=$(/usr/share/google/get_metadata_value attributes/presto_configure_alluxio_shim || false)
  if [[ "${configure_alluxio_shim}" == "true" ]]; then
    sudo sed -i 's=<configuration>=<configuration>\n  <property>\n    <name>fs.hdfs.impl</name>\n    <value>alluxio.hadoop.ShimFileSystem</value>\n  </property>\n  <property>\n    <name>fs.AbstractFileSystem.hdfs.impl</name>\n    <value>alluxio.hadoop.AlluxioShimFileSystem</value>\n  </property>\n=g' ${core_site_path}
  fi

  systemctl restart presto
}

#################
# Main function #
#################

main() {
  configure_presto
}

main "$@"
