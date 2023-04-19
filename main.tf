data "aws_availability_zones" "available" {}

locals {
  vpc_cidr                  = "10.0.0.0/16"
  Environment               = "prod"
  Owner                     = "SquareOps"
  name                      = "ASG-SquareOps"
  min_size                  = "1"
  max_size                  = "2"
  desired_capacity          = "1"
  wait_for_capacity_timeout = "0"
  region                    = "us-west-2"
  vpc_id                    = "vpc-0b3f45c5755ae1d3e"
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  azs                       = slice(data.aws_availability_zones.available.names, 0, 3)
}


module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name                      = "final-${local.name}"
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["subnet-0b1bf9f367133a41d", "subnet-0558682ffd7fa198e"]
  enabled_metrics           = local.enabled_metrics
  instance_name             = "final-${local.name}"
  min_size                  = local.min_size
  max_size                  = local.max_size
  desired_capacity          = local.desired_capacity
  wait_for_capacity_timeout = local.wait_for_capacity_timeout
  default_instance_warmup   = 300
  target_group_arns         = module.alb.target_group_arns

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
  launch_template_name        = "final-${local.name}"
  launch_template_description = "Complete launch template example"
  update_default_version      = true
  image_id                    = "ami-0db245b76e5c21ca1"
  instance_type               = "t3a.small"
  ebs_optimized               = true
  enable_monitoring           = true
  key_name                    = "adikp1"
  security_groups             = [aws_security_group.asg-sg.id]


  # IAM role & instance profile
  create_iam_instance_profile = true
  iam_role_name               = "complete-${local.name}"
  iam_role_path               = "/ec2/"
  iam_role_description        = "Complete IAM role example"
  iam_role_tags = {
    CustomIamRole = "Yes"
  }
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

 tags = {
    name  = local.name
    Owner = local.Owner
    Environment = local.Environment
  }
}

 # Scaling Policy
  resource "aws_autoscaling_policy" "asg-policy" {
    count                     = 1
    name                      = "asg-cpu-policy"
    autoscaling_group_name    = module.asg.autoscaling_group_name
    estimated_instance_warmup = 60
    policy_type               = "TargetTrackingScaling"
    target_tracking_configuration {
      predefined_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
      target_value = 50.0
    }
  }

  #ASG Security Group
  resource "aws_security_group" "asg-sg" {
    name   = "final-ASG-SG"
    vpc_id = local.vpc_id

    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      from_port   = 3000
      to_port     = 3000
      protocol    = "TCP"
      cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "final-ASG-SG"
  }
  }


#ALB 
module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 6.0"
  name               = "final-${local.name}"
  load_balancer_type = "application"
  vpc_id             = local.vpc_id
  subnets            = ["subnet-0ea38ad5d3b4d030b", "subnet-09d1456b4f93a6da4"]
  security_groups    = [aws_security_group.alb-sg.id]

  target_groups = [
    {
      name             = "final-${local.name}"
      backend_protocol = "HTTP"
      backend_port     = 3000
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
  https_listeners = [
    {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:acm:us-west-2:104004185969:certificate/5562c419-a4f7-432b-94fa-2dead851b9a2"
    }
  ]
  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]
  tags = {
    Name = "final-ALB-${local.name}"
  }
}

#ALB Security Group
resource "aws_security_group" "alb-sg" {
  name   = "final-ALB-SG"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ALL"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "final-ALB-SG"
  }
}
