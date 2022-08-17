# Create a new host pool for the hub network
locals {
  host_pool_name      = "${var.prefix}-W10-MS-2"
  session_host_prefix = "${var.prefix}-2"
}


resource "azurerm_resource_group" "host_pool" {
  name     = local.host_pool_name
  location = var.location
}

resource "azurerm_virtual_desktop_host_pool" "multisession" {
  location            = azurerm_resource_group.host_pool.location
  resource_group_name = azurerm_resource_group.host_pool.name

  name                     = local.host_pool_name
  validate_environment     = false
  description              = "Pooled Virtual Desktop Host Pool for spoke network"
  type                     = "Pooled"
  load_balancer_type       = "DepthFirst"
  maximum_sessions_allowed = 10

}

resource "azurerm_virtual_desktop_workspace" "multisession" {
  name                = "${local.host_pool_name}-westus"
  location            = azurerm_resource_group.host_pool.location
  resource_group_name = azurerm_resource_group.host_pool.name
}

resource "azurerm_virtual_desktop_application_group" "desktopapp" {
  name                = "${local.host_pool_name}-DAG"
  location            = azurerm_resource_group.host_pool.location
  resource_group_name = azurerm_resource_group.host_pool.name

  type         = "Desktop"
  host_pool_id = azurerm_virtual_desktop_host_pool.multisession.id
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "desktopapp" {
  workspace_id         = azurerm_virtual_desktop_workspace.multisession.id
  application_group_id = azurerm_virtual_desktop_application_group.desktopapp.id
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "multisession" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.multisession.id
  expiration_date = timeadd(timestamp(), "24h")
}

data "azurerm_subnet" "pool_subnet" {
  name                 = "poolSubnet"
  virtual_network_name = var.hub_vnet_name
  resource_group_name  = var.hub_vnet_resource_group
}

# Add a session host to the host pool
module "session_host" {
  source = "./session_host"

  resource_group = azurerm_resource_group.host_pool.name
  location       = azurerm_resource_group.host_pool.location
  admin_password = var.session_host_admin_password
  admin_username = var.session_host_admin_username
  subnet_id      = data.azurerm_subnet.pool_subnet.id
  vm_name        = local.session_host_prefix
  domain         = var.session_host_domain
  domainuser     = var.session_host_domainuser
  domainpassword = var.session_host_domainpassword
  oupath         = var.session_host_oupath
  regtoken       = azurerm_virtual_desktop_host_pool_registration_info.multisession.token
  hostpoolname   = azurerm_virtual_desktop_host_pool.multisession.name

}
