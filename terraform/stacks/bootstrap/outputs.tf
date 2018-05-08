output "vault_eip_public_ip" {
  value = "${aws_eip.vault.public_ip}"
}
