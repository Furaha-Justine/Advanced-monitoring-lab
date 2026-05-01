variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "docker-app"
}

variable "instance_type" {
  type    = string
  default = "t3.medium" 
}

variable "key_name" {
  type    = string
  default = "docker-app-key"
}

variable "ssh_user" {
  type    = string
  default = "ec2-user"
}

variable "app_port" {
  type    = number
  default = 5000
}