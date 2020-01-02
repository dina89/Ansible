output "ansible_server_public_address" {
    value = aws_instance.server.*.public_ip
}
output "ansible_nodes_ubuntu_public_addresses" {
    value = aws_instance.nodes-ubuntu.*.public_ip
}
output "ansible_nodes_ubuntu_private_addresses" {
    value = aws_instance.nodes-ubuntu.*.private_ip
}
output "ansible_nodes_redhat_public_addresses" {
    value = aws_instance.nodes-redhat.*.public_ip
}
output "ansible_nodes_redhat_private_addresses" {
    value = aws_instance.nodes-redhat.*.private_ip
}