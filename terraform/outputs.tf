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

output "alluxio_cluster_master_hostname" {
  value       = module.alluxio_cluster.cluster_master_hostname
  description = "Hostname of Alluxio compute cluster master."
}
#
#output "alluxio_cluster_master_public_ip" {
#  value       = module.alluxio_cluster.cluster_master_public_ip
#  description = "Public IP address of Alluxio cluster master node."
#}
#
#output "alluxio_cluster_master_web_ui" {
#  value       = "http://${module.alluxio_cluster.cluster_master_public_ip}:19999"
#  description = "Alluxio cluster master node Web UI address."
#}
