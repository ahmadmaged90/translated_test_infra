#!/bin/bash
sudo yum update -y
sudo yum install -y docker
sudo usermod -a -G docker ec2-user
sudo systemctl start docker
sudo systemctl enable docker 
echo ECS_CLUSTER=translated_test_ecs >> /etc/ecs/ecs.config