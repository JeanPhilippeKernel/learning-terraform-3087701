data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "8.0.0"

  name = "blog"
  min_size = 1
  max_size = 2

  vpc_zone_identifier = module.blog_vpc.public_subnets
  security_groups     = [module.blog_security_group.security_group_id]

  image_id            = data.aws_ami.app_ami.id
  instance_type       = var.instance_type
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  security_groups = [module.blog_security_group.security_group_id]

  http_tcp_listeners = [
    {
      port     = 80
      protocol = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix       = "blog-"
      backend_protocol  = "HTTP"
      backend_port      = 80
      target_type       = "instance"
    }
  ]

  tags = {
    Environment = "dev"
  }
}


module "blog_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name    = "blog"


  vpc_id = module.blog_vpc.vpc_id

  ingress_rules = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

