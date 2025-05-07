resource "aws_security_group" "extraexposed" {
  name        = "devports"
  description = "Development server ports"
  vpc_id      = aws_vpc.main.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0",
    ]
    from_port = 40000
    protocol  = "tcp"
    self      = false
    to_port   = 50000

  }
}
