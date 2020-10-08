#---------------Key Pair---------------

resource "aws_key_pair" "vault_key" {
  key_name   = "vault_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLgHhkLXy8iTSFLlxfVveSuMxW5cAMpyKG6OmNvgPJV6PEwL4lxvwvR7kLv5IQHK9lnva/Lm27O3mXBRh2jNPqJ4zIMrhs2FXHZtU8+KIsCbWbu4YNhpsp1CHo9JvBeccBbIiJJjGqiirLUpYepNPLUt3m42F03DZ/Bd27AVBmUSqoBJ7IH7QXv5uHU9w7lQzY/9guv+VqKvk6SJlJBPQUhHnXtDxvbS2UQlxCziBVK1txU4E2pmqJoV2JaalMM9rDi0XpVk4plhqDpthdpeQ59itu2qvZjaCcGM+mOWu4q5H5oRs8TWjgw8Uo0mKzqM2pJDAl8/kRkRMbUCKLePxD vault"
}

# --------------Vault instance---------



resource "aws_instance" "vault-instance" {
  ami                  = "${var.vault_ami}"
  instance_type        = "${var.instance_type}"
  key_name             = "vault_key"
  availability_zone    = "${var.avail_zone}"
#  vpc_security_group_ids = ["${aws_security_group.gtx_vault_dev_sg.id}","${aws_security_group.gtx_vault_private_sg.id}"]
#  subnet_id            = "${lookup(local.subnet_az_to_id, local.sorted_subnet_azs[count.index])}"
  root_block_device {
    volume_size = "${var.inst_vol_size}"
    volume_type = "${var.inst_vol_type}"
  }

  tags = {
    Name        = "Vault"
}

  user_data = <<-EOF
   #!/bin/bash
   set -x
   exec > >(tee /var/log/user-data.log|logger -t user-data ) 2>&1
   echo ------  BEGIN -----
   date '+%Y-%m-%d %H:%M:%S'

   sudo yum install -y yum-utils
   sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
   sudo yum -y install vault
   sudo rm -f /tmp/dev-server-logs
   sudo vault server -dev -dev-root-token-id=root
  EOF

}
resource "time_sleep" "wait_240_seconds" {
  depends_on = [aws_instance.vault-instance]
  create_duration = "240s"
}

resource "null_resource" "vault-mgmt" {  
  depends_on = [time_sleep.wait_240_seconds]
  connection {
    user = "ec2-user"
    agent = "false"
    private_key = file("ssh_key/vault")
    host = "${aws_instance.vault-instance.public_ip}"
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }
 
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "/tmp/script.sh | tee -a /tmp/script-logs",
    ]
  }
}
