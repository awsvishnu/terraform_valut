#---------------Key Pair---------------

resource "aws_key_pair" "vault_key" {
  key_name   = "vault_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3gCQFj6TMaZ1qE8pGAmXPRD2ZlOxxdieOXXmd/lbT6+Irgoxq8LVzLzMsIw2+c7yOGdbJY5mKsy2NLrsRGRGX+05ycXp8EOQvymU1PpvTo7QeUE5XRSDOGOPR8q4psh9SzSQhppxaZRvcyoQC/1/phVJ+SPb4QR3wq0PdZyZl8x6WN1Hdv2bVcclhKNDSQpSNDR3K661sFPGnK+MupSH2yzXQ8rLqeAcJM6PkCASlQAB1cDUdBgbjRHIijS6cauPx8Fg8GJE/klaIjp8D8MVQIl15Doo6Lmdew3LHvo87oQLhbKocKY+eaJw2zlD9ixdxG5owfQjCzyRx+ju2zyQd ec2-user@ip-172-31-43-43.us-east-2.compute.internal"
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
