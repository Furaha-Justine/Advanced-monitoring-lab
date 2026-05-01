variable "project_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.medium" 
}

variable "key_name" {
  type = string
}

variable "security_group_id" {
  type = string
}