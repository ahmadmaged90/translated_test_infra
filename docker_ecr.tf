resource "aws_ecr_repository" "translated-repo-test" {
   name = var.repo_name
}
data "aws_ecr_authorization_token" "auth_ecr" {
  
}
resource "null_resource" "docker_build_push" {
    provisioner "local-exec" {
      command = <<EOT
        aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.translated-repo-test.repository_url}
        docker build --build-arg password=${var.db_password} --build-arg username=${var.db_username} --build-arg db_url=${aws_db_instance.translated-test.endpoint} --build-arg redis_url=${aws_elasticache_cluster.translated_cache.configuration_endpoint} --build-arg db_name=${var.db_name} -t translated-test:latest
        docker tag translated-test:latest ${aws_ecr_repository.translated-repo-test.repository_url}:latest
        docker push "${aws_ecr_repository.translated-repo-test.repository_url}:latest"
      EOT
    }

}