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

output "vpc_self_link" {
  value       = length(google_compute_network.vpc) == 0 ? "" : google_compute_network.vpc[0].self_link
  description = "VPC self link"
}

output "subnet_self_link" {
  value       = length(google_compute_subnetwork.subnet) == 0 ? "" : google_compute_subnetwork.subnet[0].self_link
  description = "Subnet self link"
}
