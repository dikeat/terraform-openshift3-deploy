locals {
  all_node_ips = "${concat(var.master_private_ip, var.infra_private_ip, var.worker_private_ip, var.storage_private_ip)}"
  all_node_ips_incl_bastion = "${concat(list(var.bastion_ip_address), var.master_private_ip, var.infra_private_ip, var.worker_private_ip, var.storage_private_ip)}"
}

resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

#################################################
# Prepare to install Openshift
#################################################
data "template_file" "prepare_node_common_sh" {
  template = "${file("${path.module}/templates/prepare_node_common.sh.tpl")}"

  vars = {
    openshift_version = "${var.openshift_version}"
    ansible_version = "${var.ansible_version}"
  }
}

data "template_file" "prepare_node_sh" {
  template = "${file("${path.module}/templates/prepare_node.sh.tpl")}"

  vars = {
    docker_block_dev = "${var.docker_block_device}"
  }
}

data "template_file" "prepare_bastion_sh" {
  template = "${file("${path.module}/templates/prepare_bastion.sh.tpl")}"

  vars = {
    docker_block_dev = "${var.docker_block_device}"
  }
}

resource "null_resource" "pre_install_node_common" {
  count = "${1 + var.node_count}"

  depends_on = [
    "null_resource.dependency"
  ]

  triggers = {
    node_list = "${join(",", local.all_node_ips_incl_bastion)}"
    prepare_node_common_sh = "${data.template_file.prepare_node_common_sh.rendered}"
  }

  connection {
    type = "ssh"
    host = "${element(local.all_node_ips_incl_bastion, count.index)}"

    user        = "${var.ssh_user}"
    password    = "${var.ssh_password}"
    private_key = "${var.ssh_private_key}"

    bastion_host        = "${var.bastion_ip_address}"
    bastion_user        = "${var.bastion_ssh_user}"
    bastion_password    = "${var.bastion_ssh_password}"
    bastion_private_key = "${var.bastion_ssh_private_key}"
  }

  provisioner "file" {
    content = "${data.template_file.prepare_node_common_sh.rendered}"
    destination = "/tmp/prepare_node_common.sh"
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/prepare_node_common.sh",
        "sudo /tmp/prepare_node_common.sh",
        "rm -f /tmp/prepare_node_common.sh"
    ]
  }
}

resource "null_resource" "pre_install_cluster" {
  count = "${var.node_count}"

  depends_on = [
    "null_resource.dependency",
    "null_resource.pre_install_node_common"
  ]

  triggers = {
    prepare_node_sh = "${data.template_file.prepare_node_sh.rendered}"
  }

  connection {
    type = "ssh"
    host = "${element(local.all_node_ips, count.index)}"
    
    user        = "${var.ssh_user}"
    password    = "${var.ssh_password}"
    private_key = "${var.ssh_private_key}"

    bastion_host        = "${var.bastion_ip_address}"
    bastion_user        = "${var.bastion_ssh_user}"
    bastion_password    = "${var.bastion_ssh_password}"
    bastion_private_key = "${var.bastion_ssh_private_key}"
  }

  provisioner "file" {
    content      = "${data.template_file.prepare_node_sh.rendered}"
    destination = "/tmp/prepare_node.sh"
  }

    provisioner "remote-exec" {
      inline = [
        "chmod +x /tmp/prepare_node.sh",
        "test -e ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa",
        "sudo /tmp/prepare_node.sh",
        "rm -f /tmp/prepare_node.sh"
      ]
    }
}

resource "null_resource" "pre_install_cluster_bastion" {
  depends_on = [
    "null_resource.dependency",
    "null_resource.pre_install_node_common",
    "null_resource.copy_ansible_inventory",
    "null_resource.pre_install_cluster"
  ]

  connection {
    type = "ssh"

    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"

  }

  provisioner "file" {
    content      = "${data.template_file.prepare_bastion_sh.rendered}"
    destination = "/tmp/prepare_bastion.sh"
  }

  provisioner "remote-exec" {
      inline = [
          "chmod +x /tmp/prepare_bastion.sh",
          "test -e ~/.ssh/id_rsa && chmod 600 ~/.ssh/id_rsa",
          "sudo /tmp/prepare_bastion.sh",
          "rm -f /tmp/prepare_bastion.sh"
      ]
  }
}

resource "null_resource" "write_master_cert" {
  count = "${var.master_cert != "" ? 1 : 0}"

  connection {
    type = "ssh"
    
    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"

  }

  provisioner "file" {
    content = <<EOF
${var.master_cert}
EOF
    destination = "~/master.crt"
  }
}

resource "null_resource" "write_master_key" {
  count = "${var.master_key != "" ? 1 : 0}"

  connection {
    type = "ssh"

    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"

  }

  provisioner "file" {
    content = <<EOF
${var.master_key}
EOF
    destination = "~/master.key"
  }
}

resource "null_resource" "write_router_cert" {
  count = "${var.router_cert != "" ? 1 : 0}"

  connection {
    type = "ssh"
    
    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"

  }

  provisioner "file" {
    content = <<EOF
${var.router_cert}
EOF
    destination = "~/router.crt"
  }
}

resource "null_resource" "write_router_key" {
  count = "${var.router_key != "" ? 1 : 0}"

  connection {
    type = "ssh"
    
    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"

  }

  provisioner "file" {
    content = <<EOF
${var.router_key}
EOF
    destination = "~/router.key"
  }
}

# write out the letsencrypt CA
resource "null_resource" "write_router_ca_cert" {
  count = "${var.router_ca_cert != "" ? 1 : 0}"

  connection {
    type = "ssh"
    
    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"

  }


  provisioner "file" {
    content = <<EOF
${var.router_ca_cert}
EOF
    destination = "~/router_ca.crt"
  }
}

#################################################
# Install Openshift
#################################################
resource "null_resource" "prerequisites" {
  depends_on = [
    "null_resource.pre_install_cluster_bastion",
    "null_resource.pre_install_cluster",
    "null_resource.write_master_cert",
    "null_resource.write_master_key",
    "null_resource.write_router_cert",
    "null_resource.write_router_key",
    "null_resource.write_router_ca_cert",
    "null_resource.copy_ansible_inventory"
  ]

  triggers = {
    inventory = "${data.template_file.ansible_inventory.rendered}"
  }

  connection {
    type = "ssh"
    
    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"
  }



  provisioner "remote-exec" {
    inline = [
        "ansible-playbook -i ~/inventory.cfg /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml",
    ]
  }
}

resource "null_resource" "deploy_cluster" {
  depends_on = [
     "null_resource.prerequisites"
  ]

  triggers = {
    inventory = "${data.template_file.ansible_inventory.rendered}"
  }

  connection {
    type = "ssh"
    
    host        = "${var.bastion_ip_address}"
    user        = "${var.bastion_ssh_user}"
    password    = "${var.bastion_ssh_password}"
    private_key = "${var.bastion_ssh_private_key}"
  }

  provisioner "remote-exec" {
    inline = [
        "ansible-playbook -i ~/inventory.cfg /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml",
    ]
  }
}

resource "null_resource" "create_cluster_admin" {
    connection {
      type = "ssh"
      host = "${element(var.master_private_ip, 0)}"
      user = "${var.ssh_user}"
      private_key = "${var.ssh_private_key}"
      
      bastion_host        = "${var.bastion_ip_address}"
      bastion_user        = "${var.bastion_ssh_user}"
      bastion_password    = "${var.bastion_ssh_password}"
      bastion_private_key = "${var.bastion_ssh_private_key}"
    }

    provisioner "remote-exec" {
        when = "create"
        inline = [ 
          "oc adm policy add-cluster-role-to-user cluster-admin ${var.openshift_admin_user}"
        ]
    }

    depends_on    = ["null_resource.deploy_cluster"]
}

#################################################
# Perform post-install configurations for Openshift
#################################################
# resource "null_resource" "post_install_cluster" {
#   count = "${length(local.all_node_ips)}"
#
#   connection {
#       type = "ssh"
#       host = "${element(local.all_node_ips, count.index)}"
#       user = "${var.ssh_user}"
#       private_key = "${file(var.bastion_private_ssh_key)}"
#       bastion_host = "${var.bastion_ip_address}"
#       bastion_host_key = "${file(var.bastion_private_ssh_key)}"
#   }
#
#   provisioner "file" {
#     source      = "${path.module}/scripts/post_install_node.sh"
#     destination = "/tmp/post_install_node.sh"
#   }
#
#   provisioner "remote-exec" {
#     inline = [
#       "chmod u+x /tmp/post_install_node.sh",
#       "sudo /tmp/post_install_node.sh"
#     ]
#   }
#
#   depends_on    = ["null_resource.deploy_cluster"]
# }
