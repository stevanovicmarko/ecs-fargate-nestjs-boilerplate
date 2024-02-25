variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "security_group_name" {
  type    = string
  default = "acme-sg"
}

variable "load_balancer_name" {
  type    = string
  default = "acme-lb"
}

variable "target_group_name" {
  type    = string
  default = "acme-tg"
}

variable "ecr_repository_name" {
  type    = string
  default = "acme_repository"
}

variable "ecs_cluster_name" {
  type    = string
  default = "acme-cluster"
}

variable "ecs_service_name" {
  type    = string
  default = "acme-service"
}

variable "task_definition_name" {
  type    = string
  default = "acme-task"
}

variable "container_name" {
  type    = string
  default = "acme-container"
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "log_group" {
  type    = string
  default = "/ecs/acme-app"
}


