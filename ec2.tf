#---------------Key Pair---------------

resource "aws_key_pair" "terra_vault_key" {
  key_name   = "vault_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDI8ZYAu3MOCF61YFxWMAQVR1KG2XgtSjdqqsHcTl6Cmx1tJFDZLc6UlZuq6BEab8oiPViaGcw+3OKE+bzQ9MEJe50Y3Du0Gzpa76o9+6nUuUVkNW2RPxV6TukM6V2Bmo8AVCbuFqCM4h/AtdcMKBKm10u5/0fEH5BhHJfm8rt9/q4EK748pVAcopRjRT4delLfY6Kk4DMvecOWg72w08bHPoo58u2tvz1uOeDwSvNk41Xi7NesvvdmidI1u2cnaFPK10AnR6w2DREXCoB2lN1TuWG0vCj7CBG/p5YFCVxi9OvDwScw1cIZEf38S1AIsb0e90MOIciaIuS01klpyq5x ec2-user@ip-172-31-27-170.us-east-2.compute.internal"
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
