# Network Security Group for GitHub Runner
resource "azurerm_network_security_group" "github_runner" {
  count               = var.enable_vm_github_runner ? 1 : 0
  name                = "nsg-github-runner-${var.unique_id}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Network Security Group Association
resource "azurerm_subnet_network_security_group_association" "github_runner" {
  count                     = var.enable_vm_github_runner ? 1 : 0
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.github_runner[0].id
}

# Public IP for GitHub Runner VM
resource "azurerm_public_ip" "github_runner" {
  count               = var.enable_vm_github_runner ? 1 : 0
  name                = "pip-github-runner-${var.unique_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network Interface for GitHub Runner VM
resource "azurerm_network_interface" "github_runner" {
  count               = var.enable_vm_github_runner ? 1 : 0
  name                = "nic-github-runner-${var.unique_id}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.github_runner[0].id
  }

  tags = var.tags
}

# GitHub Runner VM
resource "azurerm_linux_virtual_machine" "github_runner" {
  count               = var.enable_vm_github_runner && var.github_runner_os_type == "linux" ? 1 : 0
  name                = "vm-github-runner-${var.unique_id}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.github_runner_vm_size
  admin_username      = "azureuser"

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.github_runner[0].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.github_runner[0].public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Generate SSH key pair for the VM
resource "tls_private_key" "github_runner" {
  count     = var.enable_vm_github_runner ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save SSH private key to local file for easy access
resource "local_file" "github_runner_private_key" {
  count           = var.enable_vm_github_runner ? 1 : 0
  content         = tls_private_key.github_runner[0].private_key_pem
  filename        = "${path.root}/.ssh/github_runner_${azurerm_linux_virtual_machine.github_runner[0].name}_key"
  file_permission = "0600"
}

# Custom Script Extension to install and configure GitHub Actions Runner
resource "azurerm_virtual_machine_extension" "github_runner" {
  count                = var.enable_vm_github_runner && var.github_runner_os_type == "linux" ? 1 : 0
  name                 = "install-github-runner"
  virtual_machine_id   = azurerm_linux_virtual_machine.github_runner[0].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    script = base64encode(templatefile("${path.module}/install-github-runner.sh", {
      github_url         = var.vm_github_runner_config.github_runner_url
      github_token       = var.vm_github_runner_config.github_runner_token
      runner_name        = "${var.vm_github_runner_config.github_runner_name}-${var.unique_id}"
      runner_work_folder = "_work"
      runner_group       = var.vm_github_runner_config.github_runner_group
      runner_labels      = "self-hosted,vm,${var.resource_group_name},${var.location},${var.unique_id}"
      repo_name          = var.vm_github_runner_config.github_repo_name
      repo_owner         = var.vm_github_runner_config.github_repo_owner
    }))
  })

  tags = var.tags

  depends_on = [azurerm_linux_virtual_machine.github_runner]
}

resource "null_resource" "deregister_runner" {
  triggers = {
    pat    = var.vm_github_runner_config.github_runner_token
    owner  = var.vm_github_runner_config.github_repo_owner
    repo   = var.vm_github_runner_config.github_repo_name
    runner = "${var.vm_github_runner_config.github_runner_name}-${var.unique_id}"
  }

  depends_on = [azurerm_linux_virtual_machine.github_runner]

  provisioner "local-exec" {
    when = destroy

    environment = {
      PAT    = self.triggers.pat
      OWNER  = self.triggers.owner
      REPO   = self.triggers.repo
      RUNNER = self.triggers.runner
    }

    command = <<-EOF
      # grab the runner ID from GitHub
      RUNNER_ID=$(
        curl -s \
          -H "Authorization: token $PAT" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/repos/$OWNER/$REPO/actions/runners" \
        | jq -r '.runners[] | select(.name=="'"$RUNNER"'") | .id'
      )

      if [ -n "$RUNNER_ID" ]; then
        curl -s -X DELETE \
          -H "Authorization: token $PAT" \
          -H "Accept: application/vnd.github.v3+json" \
          "https://api.github.com/repos/$OWNER/$REPO/actions/runners/$RUNNER_ID"
        echo "➜ Deregistered self-hosted runner ID $RUNNER_ID"
      else
        echo "➜ No runner named '$RUNNER' found; skipping"
      fi
    EOF
  }
}