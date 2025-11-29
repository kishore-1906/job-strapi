provider "aws" {
  region = var.aws_region
}

# --------------------------
# 1. VPC
# --------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "strapi-vpc" }
}

# --------------------------
# 2. Internet Gateway
# --------------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "strapi-igw" }
}

# --------------------------
# 3. Public Subnet (for EC2)
# --------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "strapi-public-a" }
}

# Another subnet for RDS subnet group
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = { Name = "strapi-public-b" }
}

# --------------------------
# 4. Route table + association
# --------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "strapi-public-rt" }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# --------------------------
# 5. Security Group for EC2 (Strapi)
# --------------------------
resource "aws_security_group" "strapi_sg" {
  name        = "strapi-ec2-sg"
  description = "Allow Strapi and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "strapi-ec2-sg" }
}

# --------------------------
# 6. Security Group for RDS
# --------------------------
resource "aws_security_group" "rds_sg" {
  name        = "strapi-rds-sg"
  description = "Allow Postgres from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.strapi_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "strapi-rds-sg" }
}

# --------------------------
# 7. DB Subnet Group for RDS
# --------------------------
resource "aws_db_subnet_group" "strapi_db_subnets" {
  name       = "strapi-db-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "strapi-db-subnet-group" }
}

# --------------------------
# 8. RDS PostgreSQL Instance
# --------------------------
resource "aws_db_instance" "strapi_db" {
  identifier              = "strapi-db"
  engine                  = "postgres"
  engine_version          = "15.6"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = var.db_username
  password                = var.db_password
  db_name                 = var.db_name
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.strapi_db_subnets.name
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = { Name = "strapi-postgres" }
}

# --------------------------
# 9. EC2 Instance (Strapi)
# --------------------------
resource "aws_instance" "strapi" {
  ami                         = "ami-0f58b397bc5c1f2e8" # Amazon Linux 2023 (ap-south-1; change if needed)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_a.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.strapi_sg.id]
  associate_public_ip_address = true

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y git

# NodeJS 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# PM2
npm install -g pm2

# Clone Strapi project
cd /home/ec2-user
git clone ${var.repo_url}

APP_DIR=$(basename ${var.repo_url} .git)
cd $APP_DIR

# Write .env for Strapi DB config
cat <<EOT > .env
NODE_ENV=production

DATABASE_CLIENT=postgres
DATABASE_HOST=${aws_db_instance.strapi_db.address}
DATABASE_PORT=5432
DATABASE_NAME=${var.db_name}
DATABASE_USERNAME=${var.db_username}
DATABASE_PASSWORD=${var.db_password}
EOT

npm install
npm run build

pm2 start npm --name strapi -- start
pm2 save
EOF

  tags = { Name = "Strapi-Server" }
}

