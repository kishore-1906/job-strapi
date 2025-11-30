variable "aws_region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  description = "job-key"
}

variable "repo_url" {
  description = "https://github.com/kishore-1906/job-strapi.git"
}

variable "db_name" {
  default     = "strapidb"
  description = "Database name for Strapi"
}

variable "db_username" {
  description = "Database username"
}

variable "db_password" {
  description = "Database password"
  sensitive   = true
}

