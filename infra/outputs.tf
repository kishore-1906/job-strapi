output "strapi_public_ip" {
  value = aws_instance.strapi.public_ip
}

output "strapi_url" {
  value = "http://${aws_instance.strapi.public_ip}:1337"
}

output "db_endpoint" {
  value = aws_db_instance.strapi_db.address
}

