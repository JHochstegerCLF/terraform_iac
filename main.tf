// Source - https://stackoverflow.com/a/63899868
// Posted by Marcin, modified by community. See post 'Timeline' for change history
// Retrieved 2026-11-06, License - CC BY-SA 4.0

data "aws_ami" "ubuntu" {

    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

output "test" {
  value = data.aws_ami.ubuntu
}


resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "example"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Main"
  }
}

resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "full-access" {
    vpc_id = aws_vpc.main.id

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }    

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }    
    
    tags = {
        Name = "full-access"
    }
}

resource "aws_network_interface" "ni" {
  subnet_id       = aws_subnet.main.id
  private_ips     = ["10.0.0.50"]
  security_groups = [aws_security_group.full-access.id]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "demo1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data     = file("script.sh")
  primary_network_interface {
    network_interface_id = aws_network_interface.ni.id
  }

  depends_on = [aws_eip.lb, aws_route_table_association.example]
}

resource "aws_eip" "lb" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.ni.id
  associate_with_private_ip = "10.0.0.50"
  depends_on                = [aws_internet_gateway.gw]
}

