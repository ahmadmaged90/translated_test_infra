#vars
variable "region" {
  type = string
  default = "eu-central-1"
}
variable "vpc_cidr" {
  type = string
  default = "10.1.0.0/24"
}
variable "subnet_cidrs_api" {
  type = list(string)
}
variable "availability_zones" {
  type = list(string)
}
variable "sub_name" {
  type = string
  default = "translates-test"
}
variable "internet_gateway_name" {
  type = string
}
variable "db_cidr" {
  type = string
}
variable "db_cidr2" {
  type = string
}
variable "db_zone" {
  type = string
}
variable "security_group_alb_name" {
  type = string
}
variable "security_group_db_name" {
  type = string
}
variable "security_group_api_name" {
  
}
variable "ingress_rules_api" {
    type = list(object({
      from_port = number
      to_port = number
      protocol = string
      cidr_blocks = list(string)
    }))
}
variable "egress_rules_api" {
    type = list(object({
      from_port = number
      to_port = number
      protocol = string
      cidr_blocks = list(string)
    }))
}
variable "template_launch_name" {
  type = string
}
variable "image_id" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "key_pair_name" {
  type = string
}
variable "alb_name" {
  type = string
}
variable "listener_port" {
  type = number
}
variable "listener_protocol" {
  type = string
}
variable "target_port" {
  type = number
}
variable "target_protocol" {
  type = string
}
variable "target_group_name" {
  type = string
}
variable "ecs_cluster_name" {
  type = string
}
variable "allocated_storage" {
  type = number
}
variable "storage_type" {
  type = string
}
variable "engine" {
  type = string
}
variable "instance_class" {
  type = string
}
variable "db_name" {
  type = string
}
variable "db_username" {
  type = string
}
variable "db_password" {
  type = string
}
variable "engine_version" {
  type = string
}
variable "security_group_cache_name" {
  type = string
}
variable "cluster_cache_id" {
  type = string
}
variable "engine_cache" {
  type = string
}
variable "cache_node_type" {
  type = string
}
variable "num_cache_nod" {
  type = number
}
variable "cache_parameter_group_name" {
  type = string
}
variable "cache_engine_version" {
  type = string
}
variable "cache_port" {
  type = number
}
variable "elasticache_security_group" {
  type = string
}
variable "elasticache_sub_group" {
  type = string
}
variable "repo_name" {
  type = string
}
variable "ecs_family_name" {
  type = string
}
variable "network_mode" {
  type = string
}
variable "task_cpu" {
  type = string
}
variable "operating_system_family" {
  type = string
}
variable "cpu_architecture" {
    type = string 
}
variable "cpu_container" {
  type = number
}
variable "ram_container" {
  type = number
}
variable "port_container" {
  type = number
}
variable "container_protocol" {
  type = string
}
variable "container_name" {
  type = string
}
variable "zone_id" {
  type = string
}
variable "domain_name" {
  type = string
}
variable "capacity_provider" {
  type = string
}
variable "main_domain_name" {
  type = string
}
variable "cache_engine" {
  type = string
}
