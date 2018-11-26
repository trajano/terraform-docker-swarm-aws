resource "aws_eip" "managers" {
  count    = "1"
  vpc      = true
}

output "manager_ip_addresses" {
  value = "${aws_eip.managers.*.public_ip}"
}
