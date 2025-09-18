module "apim" {
  source  = "Azure/avm-res-apimanagement-service/azurerm"
  version = "0.0.5"
  count   = var.apim_definition.deploy ? 1 : 0

  location                   = azurerm_resource_group.this.location
  name                       = local.apim_name
  publisher_email            = var.apim_definition.publisher_email
  resource_group_name        = azurerm_resource_group.this.name
  additional_location        = var.apim_definition.additional_locations
  certificate                = var.apim_definition.certificate
  client_certificate_enabled = var.apim_definition.client_certificate_enabled
  diagnostic_settings = {
    storage = {
      name                  = "sendToLogAnalytics-apim-${random_string.name_suffix.result}"
      workspace_resource_id = var.law_definition.resource_id != null ? var.law_definition.resource_id : module.log_analytics_workspace[0].resource_id
    }
  }
  enable_telemetry          = var.enable_telemetry
  hostname_configuration    = var.apim_definition.hostname_configuration
  min_api_version           = var.apim_definition.min_api_version
  notification_sender_email = var.apim_definition.notification_sender_email
  private_endpoints = (var.apim_definition.virtual_network_type == "None" || (var.apim_definition.virtual_network_type != "None" && var.apim_definition.sku_root == "StandardV2")) ? {
    endpoint1 = {
      private_dns_zone_resource_ids = var.flag_platform_landing_zone ? [module.private_dns_zones.apim_private_zone.resource_id] : [local.private_dns_zones_existing.apim_private_zone.resource_id]
      subnet_resource_id            = module.ai_lz_vnet.subnets["PrivateEndpointSubnet"].resource_id
    }
  } : null
  protocols                     = var.apim_definition.protocols
  public_network_access_enabled = var.apim_definition.public_network_access_enabled
  publisher_name                = var.apim_definition.publisher_name
  role_assignments              = local.apim_role_assignments
  sign_in                       = var.apim_definition.sign_in
  sign_up                       = var.apim_definition.sign_up
  sku_name                      = "${var.apim_definition.sku_root}_${var.apim_definition.sku_capacity}"
  tags                          = var.apim_definition.tags
  tenant_access                 = var.apim_definition.tenant_access
  virtual_network_subnet_id = var.apim_definition.virtual_network_type != "None" ? module.ai_lz_vnet.subnets["APIMSubnet"].resource_id : null
  virtual_network_type          = var.apim_definition.virtual_network_type
  zones                         = local.region_zones

  # ensure APIM creation waits for the networking modules that provide subnets/DNS
  depends_on = [
    module.ai_lz_vnet,
    module.private_dns_zones,
  ]
}

data "azurerm_private_dns_zone" "apim_zone_platform" {
  count               = var.flag_platform_landing_zone ? 1 : 0
  name                = (var.apim_definition.virtual_network_type == "None" || (var.apim_definition.virtual_network_type != "None" && var.apim_definition.sku_root == "StandardV2")) ? "privatelink.azure-api.net" : "azure-api.net"
  # extract resource group name from resource id:
  resource_group_name = element(split("/", module.private_dns_zones.apim_zone.resource_id), 4)
}

data "azurerm_private_dns_zone" "apim_zone_existing" {
  count               = var.flag_platform_landing_zone ? 0 : 1
  name                = (var.apim_definition.virtual_network_type == "None" || (var.apim_definition.virtual_network_type != "None" && var.apim_definition.sku_root == "StandardV2")) ? "privatelink.azure-api.net" : "azure-api.net"
  # extract resource group name from resource id:
  resource_group_name = element(split("/", local.private_dns_zones_existing.apim_zone.resource_id), 4)
}

resource "azurerm_private_dns_a_record" "apim_privatelink" {
  count               = var.apim_definition.deploy && var.apim_definition.virtual_network_type == "Internal" ? 1 : 0
  name                = local.apim_name                 
  zone_name           = var.flag_platform_landing_zone ? data.azurerm_private_dns_zone.apim_zone_platform[0].name : data.azurerm_private_dns_zone.apim_zone_existing[0].name
resource_group_name = var.flag_platform_landing_zone ? data.azurerm_private_dns_zone.apim_zone_platform[0].resource_group_name : data.azurerm_private_dns_zone.apim_zone_existing[0].resource_group_name
  
  ttl                 = 300
  records = module.apim[0].private_ip_addresses

  depends_on = [
    module.apim[0]
  ]
}