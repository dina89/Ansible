output "ansible_server_public_address" {
    value = aws_instance.server.*.public_ip
}
output "ansible_nodes_public_addresses" {
    value = aws_instance.nodes.*.public_ip
}
output "ansible_nodes_private_addresses" {
    value = aws_instance.nodes.*.private_ip
}