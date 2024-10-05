resource "aws_ecr_repository" "translated-repo-test" {
   name = var.repo_name
}
data "aws_ecr_authorization_token" "auth_ecr" {
  
}
resource "null_resource" "docker_login" {
    provisioner "local-exec" {
      command = <<EOT
        aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.translated-repo-test.repository_url}
      EOT
    }

}
resource "null_resource" "docker_build" {
    provisioner "local-exec" {
      command = <<EOT
        
        sudo docker build --build-arg password=${var.db_password} --build-arg username=${var.db_username} --build-arg db_url=${aws_db_instance.translated-test.endpoint} --build-arg redis_url=${aws_elasticache_cluster.translated_cache.cache_nodes[0].address} --build-arg db_name=${var.db_name} -t translated-test .
      EOT
    }
  
}
resource "null_resource" "docker_tag" {
    provisioner "local-exec" {
      command = <<EOT
        
        sudo docker tag translated-test:latest "${aws_ecr_repository.translated-repo-test.repository_url}:latest"
      
      EOT
    }
}
resource "null_resource" "docker_push" {
    provisioner "local-exec" {
      command = <<EOT
        sudo docker push "${aws_ecr_repository.translated-repo-test.repository_url}:latest"
      EOT
    }
  
}