/*
 * The Alluxio Open Foundation licenses this work under the Apache License, version 2.0
 * (the "License"). You may not use this work except in compliance with the License, which is
 * available at www.apache.org/licenses/LICENSE-2.0
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied, as more fully set forth in the License.
 *
 * See the NOTICE file distributed with this work for information regarding copyright ownership.
 */

output "cluster_master_hostname" {
  value       = length(module.dataproc.cluster_masters_hostnames) == 0 ? "" : module.dataproc.cluster_masters_hostnames[0]
  description = "Master hostname of the dataproc cluster"
}

#output "cluster_master_public_ip" {
#  value       = length(module.dataproc.cluster_masters_public_ips) == 0 ? "" : module.dataproc.cluster_masters_public_ips[0]
#  description = "Master public ip of the dataproc cluster"
#}

output "cluster_master_private_hostname" {
  value       = length(module.dataproc.cluster_masters_private_hostnames) == 0 ? "" : module.dataproc.cluster_masters_private_hostnames[0]
  description = "Master private hostname of the dataproc cluster"
}

output "alluxio_cluster_name" {
  value       = module.dataproc.alluxio_cluster_name
  description = "Name of the dataproc cluster"
}
