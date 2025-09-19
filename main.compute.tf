module "container_apps_managed_environment" {
  source  = "Azure/avm-res-app-managedenvironment/azurerm"
  version = "0.3.0"
  count   = var.container_app_environment_definition.deploy ? 1 : 0

  location            = azurerm_resource_group.this.location
  name                = local.container_app_environment_name
  resource_group_name = azurerm_resource_group.this.name
  diagnostic_settings = var.container_app_environment_definition.enable_diagnostic_settings ? {
    to_law = {
      name                           = "sendToLogAnalytics-cae-${random_string.name_suffix.result}"
      workspace_resource_id          = var.law_definition.resource_id != null ? var.law_definition.resource_id : module.log_analytics_workspace[0].resource_id
      log_analytics_destination_type = "AzureDiagnostics"
    }
  } : {}
  enable_telemetry                   = var.enable_telemetry
  infrastructure_resource_group_name = "rg-managed-${azurerm_resource_group.this.name}"
  infrastructure_subnet_id           = module.ai_lz_vnet.subnets["ContainerAppEnvironmentSubnet"].resource_id
  internal_load_balancer_enabled     = var.container_app_environment_definition.internal_load_balancer_enabled
  log_analytics_workspace = {
    resource_id = local.cae_log_analytics_workspace_resource_id
  }
  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = var.container_app_environment_definition.user_assigned_managed_identity_ids
  }
  role_assignments        = local.container_app_environment_role_assignments
  tags                    = var.container_app_environment_definition.tags
  workload_profile        = var.container_app_environment_definition.workload_profile
  zone_redundancy_enabled = length(local.region_zones) > 1 ? var.container_app_environment_definition.zone_redundancy_enabled : false
}

resource "azurerm_private_dns_a_record" "aca_privatelink" {
  count   = var.container_app_environment_definition.deploy ? 1 : 0
  name                = "*"                
  zone_name           = var.flag_platform_landing_zone ? module.private_dns_zones.aca_zone.name : local.private_dns_zones_existing.aca_zone.name
  resource_group_name = var.flag_platform_landing_zone ? element(split("/", module.private_dns_zones.aca_zone.resource_id), 4) : element(split("/", local.private_dns_zones_existing.aca_zone.resource_id), 4)
  
  ttl                 = 300
  records = [module.container_apps_managed_environment[0].static_ip_address]

  depends_on = [
    module.container_apps_managed_environment[0]
  ]
}