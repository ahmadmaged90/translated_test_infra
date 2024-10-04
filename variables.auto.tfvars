subnet_cidrs_api = [
    "10.1.0.0/27",
    "10.1.0.32/27"
]
availability_zones = [
    "eu-central-1a",
    "eu-central-1b"
]
internet_gateway_name = "translated_gateway"
db_zone = "eu-central-1c"
db_cidr = "10.1.0.64/27"
security_group_alb_name = "alb_sec_group"
security_group_api_name = "app_sec_group"
security_group_db_name = "db_sec_group"
ingress_rules_api = [ 
    {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = [ 
            "10.1.0.0/27",
            "10.1.0.32/27" 
        ]
    },

]
egress_rules_api = [ 
    {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = [ 
            "10.1.0.64/27" 
        ]
    }, 
]
template_launch_name = "ecs_translated_test"
image_id = "ami-0592c673f0b1e7665"
instance_type = "t2.micro"
key_pair_name = "ecs_key_pair"
alb_name = "ecs-alb-translated"
listener_port = 443
listener_protocol = "HTTPS"
target_port = 3000
target_protocol = "HTTP"
target_group_name = "ecs-target-group-translated"
ecs_cluster_name = "translated_test_ecs"
allocated_storage = 20
storage_type = "gp2"
engine = "mysql"
engine_version = "8.0"
instance_class = "db.t3.micro"
db_name = "translatedDB"
security_group_cache_name = "db_cache_group"
cluster_cache_id = "translated-cache"
engine_cache = "redis"
cache_node_type = "main.tf"
num_cache_nod = 1
cache_parameter_group_name = "default.redis3.2"
cache_engine_version = "3.2.10"
cache_port = 6379
elasticache_security_group = "elasticache-security-group-translated"
elasticache_sub_group = "elasticache-sub-group"
repo_name = "translated-repo"
ecs_family_name = "ecs-task"
network_mode = "awsvpc"
task_cpu = 256
operating_system_family = "LINUX"
cpu_architecture = "X86_64"
cpu_container = 256
ram_container = 512
port_container = 3000
container_protocol = "tcp"
container_name = "ecs_translated"