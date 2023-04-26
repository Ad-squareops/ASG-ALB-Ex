locals {
  vpc_cidr        = "10.0.0.0/16"
  Environment     = "prod"
  Owner           = "SquareOps"
  app_name        = "demosops"
  region          = "us-west-2"
  vpc_id          = "vpc-0b3f45c5755ae1d3e"
  zone_id         = "Z025421120N1PKJMEL0SR"
  domain_name     = "ldc.squareops.in"
}


module "asg" {
  source = "/home/ubuntu/ASG-ALB-Module/module"

  Environment               = local.Environment
  app_name                  = local.app_name
  health_check_type         = "EC2"
  private_subnets           = ["subnet-0b1bf9f367133a41d", "subnet-0558682ffd7fa198e"]
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1

  # Launch template
  image_id                    = "ami-0db245b76e5c21ca1"
  instance_type               = "t3a.small"


  #Load balancer
  load_balancer_type = "application"
  vpc_id             = local.vpc_id
  public_subnets     = ["subnet-0ea38ad5d3b4d030b", "subnet-09d1456b4f93a6da4"]
  zone_id            = local.zone_id
  domain_name        = local.domain_name

  target_groups = [
    {
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
  ]
  tags = {
    Name        = local.app_name
    Owner       = local.Owner
    Environment = local.Environment
  }



  asg_cpu_policy      = true
  cpu_value_threshold = 70
}
