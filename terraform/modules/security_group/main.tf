resource "aws_security_group" "this" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH and app port"

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.this.id
  description       = "App port"
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "grafana" {
  security_group_id = aws_security_group.this.id
  description       = "Grafana"
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "prometheus" {
  security_group_id = aws_security_group.this.id
  description       = "Prometheus"
  from_port         = 9090
  to_port           = 9090
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "jaeger" {
  security_group_id = aws_security_group.this.id
  description       = "Jaeger"
  from_port         = 16686
  to_port           = 16686
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "loki" {
  security_group_id = aws_security_group.this.id
  description       = "Loki"
  from_port         = 3100
  to_port           = 3100
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alertmanager" {
  security_group_id = aws_security_group.this.id
  description       = "Alertmanager"
  from_port         = 9093
  to_port           = 9093
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}