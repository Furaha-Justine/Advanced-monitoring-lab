variable "project_name" {
  description = "Prefix for resource names"
  type        = string
}

variable "app_port" {
  description = "Application port to open"
  type        = number
  default     = 5000
}