resource "aws_vpc" "translated-test" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    tags = {
        name = "translated-test"
    }
}
resource "aws_subnet" "translated_test" {
  for_each = zipmap(var.availability_zones, var.subnet_cidrs_api)
  map_public_ip_on_launch = true
  vpc_id = aws_vpc.translated-test.id
  cidr_block = each.value
  availability_zone = each.key
  tags = {
    Name = "${var.sub_name}-${each.key}"
  }
}
resource "aws_subnet" "translated_db_subnet" {
  vpc_id = aws_vpc.translated-test.id
  cidr_block = var.db_cidr
  availability_zone = var.db_zone
  tags = {
    Name = "${var.sub_name}-${var.db_zone}"
  }
}
resource "aws_internet_gateway" "internet_gateway_translated" {
  vpc_id = aws_vpc.translated-test.id
  tags = {
    Name = var.internet_gateway_name
  }
}
resource "aws_route_table" "route_table_translated" {
  vpc_id = aws_vpc.translated-test.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway_translated.id
  }
}
resource "aws_route_table_association" "subnet_route" {
  for_each = aws_subnet.translated_test
  subnet_id      = each.value.id
  route_table_id = aws_route_table.route_table_translated.id
}
resource "aws_security_group" "security_group_alb" {
  name   = var.security_group_alb_name
  vpc_id = aws_vpc.translated-test.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow https traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "security_group_db" {
  name   = var.security_group_db_name
  vpc_id = aws_vpc.translated-test.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = "false"
    cidr_blocks = var.subnet_cidrs_api
    description = "allow traffic from the api machines"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
}
resource "aws_security_group" "security_group_cache" {
  name   = var.security_group_cache_name
  vpc_id = aws_vpc.translated-test.id
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.subnet_cidrs_api
    description = "allow traffic from the api machines"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
}
resource "aws_security_group" "security_group_api" {
  name   = var.security_group_api_name
  vpc_id = aws_vpc.translated-test.id
}
resource "aws_security_group_rule" "ingress_api" {
  for_each = { for index, rule in var.ingress_rules_api : index => rule}
  type = "ingress"
  from_port = each.value.from_port
  to_port = each.value.to_port
  protocol = each.value.protocol
  cidr_blocks = each.value.cidr_blocks
  security_group_id = aws_security_group.security_group_api.id
  
}

resource "aws_security_group_rule" "egress_api" {
  for_each = { for index, rule in var.ingress_rules_api : index => rule}
  type = "egress"
  from_port = each.value.from_port
  to_port = each.value.to_port
  protocol = each.value.protocol
  cidr_blocks = each.value.cidr_blocks
  security_group_id = aws_security_group.security_group_api.id
  
}
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "ecs_key_pair"{
    key_name = var.key_pair_name
    public_key = tls_private_key.key_pair.public_key_openssh
}
resource "aws_iam_role" "ecsinstancerole" {
   name = "test_role"
   assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
}
resource "aws_iam_instance_profile" "ecs_profile" {
    name = "test_profile"
    role = "${aws_iam_role.ecsinstancerole.name}"
}
data "aws_iam_policy" "ecs_policy_role" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}
resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
    role = aws_iam_role.ecsinstancerole.name
    policy_arn = data.aws_iam_policy.ecs_policy_role.arn
}
resource "aws_launch_template" "ecs_test_translated" {
    name = var.template_launch_name
    image_id = var.image_id
    instance_type = var.instance_type
    vpc_security_group_ids = ["${aws_security_group.security_group_api.id}"]
    key_name = aws_key_pair.ecs_key_pair.key_name
    user_data = filebase64("${path.module}/ecs.sh")
    iam_instance_profile {
      name = aws_iam_instance_profile.ecs_profile.name
    }
    lifecycle {
        create_before_destroy = true
    }
    tag_specifications {
        resource_type = "instance"
         tags = {
            Name = "ecs-translated"
        }
    }
}
resource "aws_autoscaling_group" "ecs_asg" {
    vpc_zone_identifier = [for subnet in aws_subnet.translated_test : subnet.id]
    desired_capacity    = 2
    max_size            = 4
    min_size            = 2

    launch_template {
        id      = aws_launch_template.ecs_test_translated.id
        version = "$Latest"
    }
}
resource "aws_lb" "ecs_alb" {
    name               = var.alb_name
    internal           = false
    load_balancer_type = "application"
    security_groups    = ["${aws_security_group.security_group_alb.id}"]
    subnets            = [for subnet in aws_subnet.translated_test : subnet.id]

    tags = {
        Name = var.alb_name
    }
}
resource "aws_lb_listener" "ecs_alb_listener" {
    load_balancer_arn = aws_lb.ecs_alb.arn
    port              = var.listener_port
    protocol          = var.listener_protocol

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.ecs_tg.arn
    }
}
resource "aws_lb_target_group" "ecs_tg" {
    name        = var.target_group_name
    port        = var.target_port
    protocol    = var.target_protocol
    target_type = "ip"
    vpc_id      = aws_vpc.translated-test.id
    health_check {
        path = "/"
    }
}
resource "aws_db_instance" "translated-test" {
    allocated_storage = var.allocated_storage
    identifier = var.db_name
    storage_type = var.storage_type
    engine = var.engine
    engine_version = var.engine_version
    instance_class = var.instance_class
    db_name = var.db_name
    publicly_accessible = false
    vpc_security_group_ids =  ["${aws_security_group.security_group_db}"]
    db_subnet_group_name = aws_subnet.translated_db_subnet.id
    username = var.db_username
    password = var.db_password
}
resource "aws_elasticache_cluster" "translated_cache" {
    cluster_id = "cluster-example"
    engine = "redis"
    node_type = "cache.m4.large"
    num_cache_nodes = 1
    parameter_group_name = "default.redis3.2"
    engine_version = "3.2.10"
    port = 6379
    subnet_group_name = ["${aws_elasticache_subnet_group.elasticache_sub_group.id}"]
    security_group_ids = ["${aws_security_group.security_group_cache.id}"]
}
resource "aws_elasticache_security_group" "elasticache-security-group" {
    name = var.elasticache_security_group
    security_group_names = ["${aws_security_group.security_group_cache.id}"]
}
#resource "aws_elasticache_subnet_group" "elasticache_sub_group" {
#    name = var.elasticache_sub_group
#    subnet_ids = ["${aws_subnet.translated_db_subnet.id}"]
#}
resource "aws_ecs_cluster" "ecs_cluster" {
    name = var.ecs_cluster_name
}
resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
    name = "ecs_provider"

    auto_scaling_group_provider {
        auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
        managed_scaling {
            maximum_scaling_step_size = 2
            minimum_scaling_step_size = 1
            status = "ENABLED"
             target_capacity = 100
        }
    }
}

resource "aws_ecs_cluster_capacity_providers" "cluster_capacity_provider" {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
    capacity_providers = ["${aws_ecs_capacity_provider.ecs_capacity_provider.name}"]

    default_capacity_provider_strategy {
        base              = 1
        weight            = 100
        capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    }
}
resource "aws_iam_role" "ecstaskrole" {
   name = "test_role"
   assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "Service": [
                        "ecs-tasks.amazonaws.com"
                    ]
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
}
data "aws_iam_policy" "ecs_task_role" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs_task_attachment" {
    role = aws_iam_role.ecstaskrole
    policy_arn = data.aws_iam_policy.ecs_task_role.arn
}
resource "aws_ecs_task_definition" "ecs_task_definition" {
    family = var.ecs_family_name
    network_mode = var.network_mode
    execution_role_arn = aws_iam_role.ecstaskrole.arn
    cpu                = var.task_cpu
    runtime_platform {
        operating_system_family = var.operating_system_family
        cpu_architecture = var.cpu_architecture
    }
    container_definitions = jsonencode([
        {
            name  = "${var.container_name}"
            image = "${aws_ecr_repository.translated-repo-test.repository_url}:latest"
            cpu = "${var.cpu_container}"
            memory = "${var.ram_container}"
            essential = true
            portMappings = [
                {
                    containerPort = "${var.port_container}"
                    hostPort = 0
                    protocol = "${var.container_protocol}"
                }
            ]
        }
    ])
}
resource "aws_ecs_service" "ecs_service" {
    name            = "my-ecs-service"
    cluster         = aws_ecs_cluster.ecs_cluster.id
    task_definition = aws_ecs_task_definition.ecs_task_definition.arn
    desired_count   = 2

    network_configuration {
        subnets         = [for subnet in aws_subnet.translated_test : subnet.id]
        security_groups = [aws_security_group.security_group_api.id]
    }
    force_new_deployment = true
    placement_constraints {
        type = "distinctInstance"
    }

    triggers = {
        redeployment = timestamp()
    }

    capacity_provider_strategy {
        capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
        weight            = 100
    }
    load_balancer {
        target_group_arn = aws_lb_target_group.ecs_tg.arn
        container_name   = "dockergs"
        container_port   = 3000
    }
    depends_on = [aws_autoscaling_group.ecs_asg]
}