resource "aws_eip" "managers" {
  count    = "2"
  vpc      = true
}

output "manager_ip_addresses" {
  value = "${aws_eip.managers.*.public_ip}"
}
