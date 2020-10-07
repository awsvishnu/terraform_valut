#---------------Key Pair---------------

resource "aws_key_pair" "tform" {
  key_name   = "tform"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkbLoljpG/xlgGmpdmn8F1XkDMtOVtzVt2TKGJenQelFMgfuy939Co+6vdDx4jVD/Fp9pLYcTTw6cbRxQ7NBhf5QVvlVNn5avyhCMr76VOufW5WSDVEsDwGHzPRlk5qxEjfuLflhKRJgJNJof2jvkVscgbizzLrEDE4PxlVAVea2DXIBB3DuXxJcAyW57lyjQklhUflIORWBHq07NINXtL7sRUcgduHys3JA+N0VueSpdnsDK6Msg1bEN1GUetIx8m7XPVa94T5N94hUscoew5zSTI8ARcRCQ4mgM1RMrQgIZmzeiIGEYPWI4nr6Vy0sEx6dFEJFObBwNLM+z3EqlX ec2-user@ip-172-31-43-43.us-east-2.compute.internal"
}

# --------------Vault instance---------



resource "aws_instance" "vault-instance" {
  ami                  = "ami-03657b56516ab7912"
  instance_type        = "t2.micro"
  key_name             = "tform"
  availability_zone    = "us-east-2a"
#  vpc_security_group_ids = ["${aws_security_group.gtx_vault_dev_sg.id}","${aws_security_group.gtx_vault_private_sg.id}"]
#  subnet_id            = "${lookup(local.subnet_az_to_id, local.sorted_subnet_azs[count.index])}"
  root_block_device {
    volume_size = "15"
    volume_type = "gp2"
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
    private_key = file("ssh_key/id_rsa")
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
