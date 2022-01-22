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
variable "master_config" {
  description = "Master instance(s) configuration details"
  type = object({
    instance_count = number
    machine_type   = string
  })
  default = {
    instance_count = 1 // master num of two is unsupported in dataproc
    machine_type   = "n1-highmem-4"
  }
}

variable "worker_config" {
  description = "Worker instance(s) configuration details"
  type = object({
    num_local_ssds = number
    // dataproc requires at least two or more workers
    instance_count = number
    machine_type   = string
  })
  default = {
    num_local_ssds = 1
    instance_count = 2
    machine_type   = "n1-highmem-4"
  }
}

variable "metadata" {
  description = "A map of Compute Engine metadata entries to add to all instances"
  type        = map(string)
  default     = {}
}

variable "optional_components" {
  description = "List of optional components to activate on the cluster"
  type        = list(string)
  default     = []
}

variable "override_properties" {
  description = "List of override and additional properties (key/value pairs) used to modify various aspects of the common configuration files used when creating a cluster"
  type        = map(string)
  default     = {}
}

variable "initialization_actions" {
  description = "List of additional initialization actions to execute after provisioning"
  type        = list(string)
  default     = []
}

variable "staging_bucket" {
  description = "The cloud storage staging bucket used to stage files"
  type        = string
  default     = null
}

variable "dataproc_image_version" {
  description = "The image version for dataproc cluster"
  type        = string
  default     = "1.4.27-debian10"
}
