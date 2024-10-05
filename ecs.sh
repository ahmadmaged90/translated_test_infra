#!/bin/bash
sudo usermod -a -G docker ec2-user
sudo systemctl start docker
sudo systemctl enable docker 
echo ECS_CLUSTER=translated_test_ecs >> /etc/ecs/ecs.config