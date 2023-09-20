## Declare VPC, 2 Public Subnets, Internet Gateway, and Route Table

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "My VPC"
  }
}
resource "aws_subnet" "public_us_east_1a" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public Subnet us-east-1a"
  }
}
resource "aws_subnet" "public_us_east_1b" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Public Subnet us-east-1b"
  }
}
resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "My VPC - Internet Gateway"
  }
}
resource "aws_route_table" "my_vpc_public" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_vpc_igw.id
  }
  tags = {
    Name = "Public Subnets Route Table for My VPC"
  }
}
resource "aws_route_table_association" "my_vpc_us_east_1a_public" {
  subnet_id = aws_subnet.public_us_east_1a.id
  route_table_id = aws_route_table.my_vpc_public.id
}
resource "aws_route_table_association" "my_vpc_us_east_1b_public" {
  subnet_id = aws_subnet.public_us_east_1b.id
  route_table_id = aws_route_table.my_vpc_public.id
}

## Declare Security Group for the Instances

resource "aws_security_group" "allow_http" {
  name = "allow_http"
  description = "Allow HTTP Inbound Connections"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow HTTP Security Group"
  }
}

  ## Declare Launch Configuration

  resource "aws_launch_configuration" "web" {
  name_prefix = "web-"
  image_id = "data.aws_ami.amazon_linux.id"
  instance_type = "t2.micro"
  key_name = "Web-App-Key"
  security_groups = [ aws_security_group.allow_http.id ]
  associate_public_ip_address = true
  ## script to execute at boot
  ## install and start nginx
  user_data = <<USER_DATA
  #!/bin/bash
  yum update
  yum -y install nginx
  chkconfig nginx on
  service nginx start
  USER_DATA
  ## Prevent Outage. Create Instances from Launch Configuration Before Destroying Old Instances.
  lifecycle {
    create_before_destroy = true
  }
}

## Declare Elastic Load Balancer

resource "aws_security_group" "elb_http" {
  name = "elb_http"
  description = "Allow HTTP Traffic to Instances Through Elastic Load Balancer"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow HTTP Through ELB Security Group"
  }
}
resource "aws_elb" "web_elb" {
  name = "web-elb"
  security_groups = [
    aws_security_group.elb_http.id
  ]
  subnets = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]
  cross_zone_load_balancing = true
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

## Declare Auto Scaling Group

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"
  min_size = 1
  desired_capacity = 2
  max_size = 4
  health_check_type = "ELB"
  load_balancers = [
    aws_elb.web_elb.id
  ]
  launch_configuration = aws_launch_configuration.web.name
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"
  vpc_zone_identifier = [
    aws_subnet.public_us_east_1a.id,
    aws_subnet.public_us_east_1b.id
  ]
  # Redeploy Without Outage
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key = "Name"
    value = "web"
    propagate_at_launch = true
  }
}

/*
## Output Load Balancer DNS Name

output "elb_dns_name" {
  value = aws_elb.web_elb.dns_name
}
*/

## UP : Auto Scaling Policy & CloudWatch Metric Alarm
## increase ASG size by one instance every 300 seconds if its total CPU utilization is greater or equals 60%

resource "aws_autoscaling_policy" "web_policy_up" {
  name = "web_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_up" {
  alarm_name = "web_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
  alarm_description = "This Metric Monitor EC2 Instance CPU Utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_up.arn ]
}

## DOWN : Auto Scaling Policy & CloudWatch Metric Alarm
## decrease ASG size by one instance every 300 seconds if its total CPU utilization is less or equals 10%

resource "aws_autoscaling_policy" "web_policy_down" {
  name = "web_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}
resource "aws_cloudwatch_metric_alarm" "web_cpu_alarm_down" {
  alarm_name = "web_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "10"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
  alarm_description = "This Metric Monitor EC2 Instance CPU Utilization"
  alarm_actions = [ aws_autoscaling_policy.web_policy_down.arn ]
}