resource "aws_instance" "main" {
    ami = local.ami_id
    instance_type = "t3.micro"
    subnet_id = local.private_subnet_id #public subnet ids
    vpc_security_group_ids = [local.sg_id]
   
tags = merge(
        {
        Name = "${var.project}-${var.environment}-${var.component}"
    },
        local.common_tags
    
    )
}

# connection

resource "terraform_data"  "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

  connection {
    type = "ssh"
    user = "ec2-user"
    password = "DevOps321"
    host = aws_instance.main.private_ip

  }

  provisioner "file" {

    source = "bootstrap.sh" #local file path
    destination = "tmp/bootstrap.sh"  # Deatination path on the remote machine

}

  provisioner "remote-exec" {
    inline = [
       "chmod +x /tmp/bootstrap.sh",
       "sudo sh /tmp/bootstramp.sh ${var.component} ${var.environment} ${var.app_version}" #add rabbitmq here and also directly you can give env

    ]
  }
}

#to stop instance

resource "aws_ec2_instance_state" "main" {

    instance_id = aws_instance.main.id
    state = "stopped"
    depends_on = [terraform_data.main]
}


#take ami

resource "aws_ami_from_instance" "main" {
   name = "${var.project}-${var.environment}-${var.component}"
   source_instance_id =   aws_instance.main.id 
   depends_on = [aws_ec2_instance_state.main]
   tags = merge(
    {
       Name = "${var.project}-${var.environment}-${var.component}"
    },
        local.common_tags)
    
}


# target group creation

resource "aws_lb_target_group" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  port = local.port_number
  protocol = "HTTP"
  vpc_id = local.vpc_id
  deregistration_delay = 60

  health_check {
    healthy_threshold = 2
    interval = 10
    matcher = "200-299"
    path = local.health_check_path
    port = local.port_number
    protocol = "HTTP"
    timeout = 2
    unhealthy_threshold = 3
  }
}



# launch template

resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  image_id = aws_ami_from_instance.main.id

  # once autoscaling sees less traffic, it will terminate the instance
  instance_initiated_shutdown_behavior = "terminate"
  
  instance_type = "t3.micro"

  vpc_security_group_ids = [local.sg_id]
  
  # each time we apply terraform this version will be updated as default
  update_default_version = true

  # tags for instances created by launch template through autoscaling
  tag_specifications {
    resource_type = "instance"

    tags = merge(
        {
        Name = "${var.project}-${var.environment}-${var.component}"
    },
        local.common_tags
    )
  
}

  # tags for volumes created b instances
  
  tag_specifications {
    resource_type = "instance"

    tags = merge(
        {
        Name = "${var.project}-${var.environment}-${var.component}"
    },
        local.common_tags
    )
  }
}
 

 

# auto scaling group

resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-${var.component}"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false

  launch_template {
    id = aws_launch_template.main.id
    version = "$Latest"
  }

  vpc_zone_identifier       = [local.private_subnet_id]
  target_group_arns = [aws_lb_target_group.main.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  dynamic "tag" {
    for_each = merge(
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      },
        local.common_tags
    )
    content {
      key = tag.key
      value = tag.value
      propagate_at_launch = true 
    }
  }
  # with in 15m autoscalling should be successful

  timeouts {
    delete = "15m"
  }
}

# Auto-scaling -policy

resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name = "${var.project}-${var.environment}-${var.component}"
  policy_type = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }


}


#listener rule
#this depends on target group
#if frontend frontend-dev-prasanna.fun

resource "aws_lb_listener_rule" "main" {
 listener_arn = local.alb_listener_arn
  priority = var.rule_priority

  action {
    type = "forward"
    traget_group_arn = aws_lb_target_group.main.arn
  }
  condition {
    host_header {
      values = [local.host_header]
    }
  }
  }


resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]
  depends_on = [aws_autoscaling_policy.main]
  

 # it executes in bastion

  provisioner "local-exec" {
     command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
  
}
