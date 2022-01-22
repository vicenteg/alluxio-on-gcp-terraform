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

// Name variables
// --------------
variable "use_default_name" {
  description = "Whether to use the default readable names for created resources. Random string will be attached to the default readable resource names if false. Recommended to set to false for production."
  type        = bool
  default     = false
}

variable "custom_name" {
  description = "Name to prefix resources with."
  type        = string
  default     = ""
}
