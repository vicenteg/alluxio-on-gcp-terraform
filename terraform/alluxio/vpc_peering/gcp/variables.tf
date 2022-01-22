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

variable "cloud_compute_vpc_self_link" {
  description = "VPC self link of the cloud compute cluster"
  type        = string
}

variable "cloud_compute_subnet_self_link" {
  description = "Subnet self link of the cloud compute cluster"
  type        = string
}

variable "on_prem_vpc_self_link" {
  description = "Vpc self link of the on-prem cluster"
  type        = string
}

variable "on_prem_subnet_self_link" {
  description = "Subnet self link of the on-prem cluster"
  type        = string
}
