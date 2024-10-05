resource "aws_vpc" "translated-test" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    tags = {
        name = "translated-test"
    }
}
resource "aws_subnet" "translated_test" {
    for_each = zipmap(var.availability_zones, var.subnet_cidrs_api)
  #map_public_ip_on_launch = true
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
resource "aws_subnet" "translated_db_subnet2" {
    vpc_id = aws_vpc.translated-test.id
    cidr_block = var.db_cidr2
    tags = {
        Name = "${var.sub_name}-db2"
    }
}
resource "aws_subnet" "public_subnet" {
    depends_on = [ aws_subnet.translated_test ]
    vpc_id = aws_vpc.translated-test.id
    cidr_block = var.public_subnet
    availability_zone = var.public_zone
    tags = {
        Name = "${var.sub_name}-public"
    }
}
resource "aws_internet_gateway" "internet_gateway_translated" {
  depends_on = [ aws_subnet.public_subnet,aws_subnet.translated_test ]
  vpc_id = aws_vpc.translated-test.id
  tags = {
    Name = var.internet_gateway_name
  }
}
resource "aws_eip" "Nat-Gateway-EIP" {
}
resource "aws_nat_gateway" "nat_gateway" {
    depends_on = [
        aws_eip.Nat-Gateway-EIP,
        aws_subnet.public_subnet,
        aws_internet_gateway.internet_gateway_translated
    ]
    allocation_id = aws_eip.Nat-Gateway-EIP.id
    subnet_id = aws_subnet.public_subnet.id
    tags = {
        Name = "nat-gateway_translated"
    }
}
resource "aws_route_table" "route_table_translated" {
    depends_on = [  
        aws_nat_gateway.nat_gateway,
        aws_route_table.nat_route
    ]
    vpc_id = aws_vpc.translated-test.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway_translated.id
    }
}
resource "aws_route_table" "nat_route" {
    depends_on = [ aws_nat_gateway.nat_gateway ]
    vpc_id = aws_vpc.translated-test.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway.id
   }
}
resource "aws_route_table_association" "subnet_route" {
    depends_on = [ aws_nat_gateway.nat_gateway, aws_subnet.public_subnet, aws_route_table.nat_route ]
    for_each = aws_subnet.translated_test
    subnet_id      = each.value.id
    route_table_id = aws_route_table.nat_route.id
}
resource "aws_route_table_association" "public_subnet_route" {
  depends_on = [ aws_nat_gateway.nat_gateway, aws_subnet.public_subnet, aws_route_table.nat_route, aws_route_table_association.subnet_route ] 
  subnet_id      = aws_subnet.public_subnet.id
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
    cidr_blocks = ["${var.vpc_cidr}"]
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
    cidr_blocks = ["${var.vpc_cidr}"]
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
  for_each = { for index, rule in var.egress_rules_api : index => rule}
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
resource "local_file" "private_key" {
    content  = tls_private_key.key_pair.private_key_pem
    filename = "${path.module}/ecs-key.pem"
}
 
output "public_key" {
    value = tls_private_key.key_pair.private_key_openssh
    sensitive = true
}
resource "aws_key_pair" "ecs_key_pair"{
    key_name = var.key_pair_name
    public_key = tls_private_key.key_pair.public_key_openssh
}
resource "aws_iam_role" "ecsinstancerole" {
   name = "ecsinstancerole"
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
data "aws_ami" "ecs_optimized" {
    most_recent = true
    filter {
        name = "name"
        values = ["amzn2-ami-ecs-hvm-2.0.20230509-x86_64-ebs"]
    }
}
resource "aws_launch_template" "ecs_test_translated" {
    name = var.template_launch_name
    image_id = data.aws_ami.ecs_optimized.id
    instance_type = var.instance_type
    vpc_security_group_ids = ["${aws_security_group.security_group_api.id}"]
    key_name = aws_key_pair.ecs_key_pair.key_name
    user_data = filebase64("${path.module}/ecs.sh")
    iam_instance_profile {
      name = aws_iam_instance_profile.ecs_profile.name
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
data "aws_route53_zone" "zone" {
    zone_id = var.zone_id
  
}
resource "aws_acm_certificate" "cert" {
    domain_name = var.domain_name
    validation_method = "DNS"
    subject_alternative_names = ["${var.main_domain_name}"]
    tags = {
      Name = "translated-cert"
    }
}
resource "aws_route53_record" "cert_record" {
    for_each = {
    for atrb in aws_acm_certificate.cert.domain_validation_options : atrb.domain_name => {
      name  = atrb.resource_record_name
      type  = atrb.resource_record_type
      value = atrb.resource_record_value
    }
  }
 
    zone_id = data.aws_route53_zone.zone.zone_id
    name = each.value.name 
    type    = each.value.type
    ttl     = 300
    records = [each.value.value]
}
resource "aws_acm_certificate_validation" "cert_validation" {
    certificate_arn = aws_acm_certificate.cert.arn
    validation_record_fqdns = [for domain, record in aws_route53_record.cert_record : record.fqdn]
}
resource "aws_lb" "ecs_alb" {
    name               = var.alb_name
    internal           = false
    load_balancer_type = "application"
    security_groups    = ["${aws_security_group.security_group_alb.id}"]
    subnets            = [aws_subnet.public_subnet.id, aws_subnet.translated_test["eu-central-1c"].id, aws_subnet.translated_test["eu-central-1b"].id]

    tags = {
        Name = var.alb_name
    }
}
resource "aws_lb_listener" "ecs_alb_listener" {
    load_balancer_arn = aws_lb.ecs_alb.arn
    port              = var.listener_port
    protocol          = var.listener_protocol
    certificate_arn = aws_acm_certificate.cert.arn

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
resource "aws_db_subnet_group" "sub_db_group" {
    name       = "subnet-${var.db_name}"
    subnet_ids = [ aws_subnet.translated_db_subnet.id, aws_subnet.translated_db_subnet2.id ]
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
    availability_zone = var.db_zone
    vpc_security_group_ids =  ["${aws_security_group.security_group_db.id}"]
    db_subnet_group_name = aws_db_subnet_group.sub_db_group.id
    username = var.db_username
    password = var.db_password
    skip_final_snapshot = true
    
}
resource "aws_elasticache_cluster" "translated_cache" {
    cluster_id = "cluster-example"
    engine = "redis"
    node_type = "cache.t2.micro"
    num_cache_nodes = 1
    parameter_group_name = "default.redis4.0"
    engine_version = var.cache_engine
    port = 6379
    subnet_group_name = aws_elasticache_subnet_group.elasticache_sub_group.id
    security_group_ids = ["${aws_security_group.security_group_cache.id}"]
}
output "elasticache_endpoint" {
    value = aws_elasticache_cluster.translated_cache.configuration_endpoint
  
}
resource "aws_elasticache_subnet_group" "elasticache_sub_group" {
    name = var.elasticache_sub_group
    subnet_ids = ["${aws_subnet.translated_db_subnet.id}"]
}
resource "aws_ecs_cluster" "ecs_cluster" {
    name = var.ecs_cluster_name
}
resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
    name = var.capacity_provider

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
   name = "ecstaskrole"
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
    role = aws_iam_role.ecstaskrole.name
    policy_arn = "${data.aws_iam_policy.ecs_task_role.arn}"
}
resource "aws_iam_role_policy_attachment" "ecs_task_attachment_logs" {
    role = aws_iam_role.ecstaskrole.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/your-log-group"
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
            logconfiguration = {
                logDriver = "awslogs"
                options = {
                    "awslogs-group" = "${aws_cloudwatch_log_group.ecs_log_group.name}"
                    "awslogs-region"       = "${var.region}"
                    "awslogs-stream-prefix" = "ecs"
                }                
            }
            portMappings = [
                {
                    containerPort = "${var.port_container}"
                    hostPort = "${var.port_container}"
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
        redeployment = plantimestamp()
    }

    capacity_provider_strategy {
        capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
        weight            = 100
    }
    load_balancer {
        target_group_arn = aws_lb_target_group.ecs_tg.arn
        container_name   = var.container_name
        container_port   = 3000
    }
    depends_on = [aws_autoscaling_group.ecs_asg]
}