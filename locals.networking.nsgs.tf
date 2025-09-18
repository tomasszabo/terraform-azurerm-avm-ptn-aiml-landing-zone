#TODO: Come up with a standard set of NSG rules for the AI ALZ. This is a starting point.
locals {
  base_nsg_rules = {
    "rule01" = {
      name                         = "Allow-RFC-1918-Any"
      access                       = "Allow"
      destination_address_prefixes = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      destination_port_range       = "*"
      direction                    = "Outbound"
      priority                     = 100
      protocol                     = "*"
      source_address_prefixes      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      source_port_range            = "*"
    }
    "appgw_rule01" = {
      name                         = "Allow-AppGW_Management"
      access                       = "Allow"
      destination_address_prefix   = "*"
      destination_port_range       = "65200-65535"
      direction                    = "Inbound"
      priority                     = 110
      protocol                     = "Tcp"
      source_address_prefix        = "GatewayManager"
      source_port_range            = "*"
    }
    "appgw_rule02" = {
      name                         = "Allow-AppGW_Web"
      access                       = "Allow"
      destination_address_prefixes = try(var.vnet_definition.subnets["AppGatewaySubnet"].address_prefix, null) != null ? [var.vnet_definition.subnets["AppGatewaySubnet"].address_prefix] : [cidrsubnet(var.vnet_definition.address_space, 4, 5)]
      destination_port_ranges      = ["80", "443"]
      direction                    = "Inbound"
      priority                     = 120
      protocol                     = "Tcp"
      source_address_prefix        = "*"
      source_port_range            = "*"
    }
    "appgw_rule03" = {
      name                         = "Allow-AppGW_LoadBalancer"
      access                       = "Allow"
      destination_address_prefixes = try(var.vnet_definition.subnets["AppGatewaySubnet"].address_prefix, null) != null ? [var.vnet_definition.subnets["AppGatewaySubnet"].address_prefix] : [cidrsubnet(var.vnet_definition.address_space, 4, 5)]
      destination_port_range       = "*"
      direction                    = "Inbound"
      priority                     = 4000
      protocol                     = "*"
      source_address_prefix        = "AzureLoadBalancer"
      source_port_range            = "*"
    }
    "apim_rule01" = {
      name                         = "Allow-APIM_Internal_Management"
      access                       = "Allow"
      destination_address_prefix   = "VirtualNetwork"
      destination_port_range       = "3443"
      direction                    = "Inbound"
      priority                     = 200
      protocol                     = "Tcp"
      source_address_prefix        = "ApiManagement"
      source_port_range            = "*"
    }
    "apim_rule02" = {
      name                         = "Allow-APIM_Internal_LoadBalancer"
      access                       = "Allow"
      destination_address_prefix   = "VirtualNetwork"
      destination_port_range       = "6390"
      direction                    = "Inbound"
      priority                     = 210
      protocol                     = "Tcp"
      source_address_prefix        = "AzureLoadBalancer"
      source_port_range            = "*"
    }
    "apim_rule03" = {
      name                         = "Allow-APIM_Internal_Storage"
      access                       = "Allow"
      destination_address_prefix   = "Storage"
      destination_port_range       = "443"
      direction                    = "Outbound"
      priority                     = 220
      protocol                     = "Tcp"
      source_address_prefix        = "VirtualNetwork"
      source_port_range            = "*"
    }
    "apim_rule04" = {
      name                         = "Allow-APIM_Internal_SQL"
      access                       = "Allow"
      destination_address_prefix   = "SQL"
      destination_port_range       = "1433"
      direction                    = "Outbound"
      priority                     = 230
      protocol                     = "Tcp"
      source_address_prefix        = "VirtualNetwork"
      source_port_range            = "*"
    }
    "apim_rule05" = {
      name                         = "Allow-APIM_Internal_KeyVault"
      access                       = "Allow"
      destination_address_prefix   = "AzureKeyVault"
      destination_port_range       = "443"
      direction                    = "Outbound"
      priority                     = 240
      protocol                     = "Tcp"
      source_address_prefix        = "VirtualNetwork"
      source_port_range            = "*"
    }
    "apim_rule06" = {
      name                         = "Allow-APIM_Internal_Monitor"
      access                       = "Allow"
      destination_address_prefix   = "AzureMonitor"
      destination_port_ranges      = [1886, 443]
      direction                    = "Outbound"
      priority                     = 250
      protocol                     = "Tcp"
      source_address_prefix        = "VirtualNetwork"
      source_port_range            = "*"
    }

  }
  nsg_name = try(var.nsgs_definition.name, null) != null ? var.nsgs_definition.name : (var.name_prefix != null ? "${var.name_prefix}-ai-alz-nsg" : "ai-alz-nsg")
  nsg_rules = merge(
    local.base_nsg_rules,
    var.nsgs_definition.security_rules
  )
}
