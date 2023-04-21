locals {
  vpc_cidr                  = "10.0.0.0/16"
  Environment               = "prod"
  Owner                     = "SquareOps"
  app_name                  = "test"
  region                    = "us-west-2"
  vpc_id                    = "vpc-0b3f45c5755ae1d3e"
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  zone_id                   = "Z025421120N1PKJMEL0SR"
  domain_name               = "ldc.squareops.in"
  host_headers              = "testadi.ldc.squareops.in"
  hosted_zone_id            = "Z025421120N1PKJMEL0SR"
  cert_enable               = true
}


module "asg" {
  source = "github.com/Ad-squareops/ASG-ALB-Module/module"

  Environment               = local.Environment
  app_name                  = local.app_name
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["subnet-0b1bf9f367133a41d", "subnet-0558682ffd7fa198e"]
  enabled_metrics           = local.enabled_metrics
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300


  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }


  # Launch template
  launch_template_description = "Complete launch template example"
  update_default_version      = true
  image_id                    = "ami-0db245b76e5c21ca1"
  instance_type               = "t3a.small"
  ebs_optimized               = true
  enable_monitoring           = true

  

#Load balancer
  #name               = local.Environment
  load_balancer_type = "application"
  vpc_id             = local.vpc_id
  public_subnets     = ["subnet-0ea38ad5d3b4d030b", "subnet-09d1456b4f93a6da4"]
  zone_id            = local.zone_id
  domain_name        = local.domain_name
  host_headers       = local.host_headers
  hosted_zone_id     = local.hosted_zone_id

  target_groups = [
    {
      name             = local.Owner
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
        matcher             = "404"
      }
    }
  ]
  tags = {
    Name        = local.app_name
    Owner       = local.Owner
    Environment = local.Environment
  }
}
