terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.21"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  subscription_id = "77e22c81-77e2-4a20-8f29-17a9443d8e33"
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
  }
}

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.3.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# Get the deployer IP address to allow for public write to the key vault. This is to make sure the tests run.
# In practice your deployer machine will be on a private network and this will not be required.
data "http" "ip" {
  url = "https://api.ipify.org/"
  retry {
    attempts     = 5
    max_delay_ms = 1000
    min_delay_ms = 500
  }
}

#create a sample hub to mimic an existing network landing zone configuration
module "example_hub" {
  source = "../modules/example_hub_vnet"

  deployer_ip_address = "${data.http.ip.response_body}/32"
  location            = "swedencentral"
  resource_group_name = "ai-lz-hub-03-rg"
  vnet_definition = {
    address_space = "10.10.0.0/24"
  }
  enable_telemetry = var.enable_telemetry
  name_prefix      = "${module.naming.resource_group.name_unique}-hub"
}

module "avm-ptn-aiml-landing-zone" {
  source  = "../.."
  
  location            = "swedencentral" 
  resource_group_name = "ai-lz-03-rg"
	vnet_definition = {
    name          = "ai-lz-vnet-default"
    address_space = "192.168.0.0/23"                                                                 # has to be out of 192.168.0.0/16 currently. Other RFC1918 not supported for foundry capabilityHost injection.
    dns_servers = [for key, value in module.example_hub.dns_resolver_inbound_ip_addresses  : value], # Use the DNS resolver inbound IPs from the example hub
    create_vnet_peering = true
    vnet_peering_configuration = {
      peer_vnet_resource_id = module.example_hub.virtual_network_resource_id
      firewall_ip_address   = module.example_hub.firewall_ip_address
    }
  }
  ai_foundry_definition = {
    purge_on_destroy = true
    ai_foundry = {
      create_ai_agent_service = true
    }
    ai_model_deployments = {
      "gpt-4o" = {
        name = "gpt-4.1"
        model = {
          format  = "OpenAI"
          name    = "gpt-4.1"
          version = "2025-04-14"
        }
        scale = {
          type     = "GlobalStandard"
          capacity = 1
        }
      }
    }
    ai_projects = {
      project_1 = {
        name                       = "project-1"
        description                = "Project 1 description"
        display_name               = "Project 1 Display Name"
        create_project_connections = true
        cosmos_db_connection = {
          new_resource_map_key = "this"
        }
        ai_search_connection = {
          new_resource_map_key = "this"
        }
        storage_account_connection = {
          new_resource_map_key = "this"
        }
      }
    }
    ai_search_definition = {
      this = {
        enable_diagnostic_settings = false
      }
    }
    cosmosdb_definition = {
      this = {
        enable_diagnostic_settings = false
        consistency_level          = "Session"
      }
    }
    key_vault_definition = {
      this = {
        enable_diagnostic_settings = false
      }
    }

    storage_account_definition = {
      this = {
        enable_diagnostic_settings = false
        shared_access_key_enabled  = true #configured for testing
        endpoints = {
          blob = {
            type = "blob"
          }
        }
      }
    }
  }
  apim_definition = {
    name            = "ai-alz-apim-6oyt"
    publisher_email = "admin@contoso.com"
    publisher_name  = "Contoso"
    sku_capacity    = 3
    virtual_network_type = "Internal"
    public_network_access_enabled = true
  }
  app_gateway_definition = {
    backend_address_pools = {
      example_pool = {
        name  = "example-backend-pool"
        fqdns = ["ai-alz-apim-6oyt.azure-api.net"]
      }
    }

    probe_configurations = {
      apim-probe = {
        name                = "apim-probe"
        protocol            = "Https"
        host                = "ai-alz-apim-6oyt.azure-api.net"
        path                = "/status-0123456789abcdef"
        interval            = 30
        timeout             = 30
        unhealthy_threshold = 3
        match = {
          status_code = ["200-399"]
        }
      }
    }
   
    backend_http_settings = {
      example_http_settings = {
        name     = "example-https-settings"
        port     = 443
        protocol = "Https"
        probe_name  = "apim-probe"
        pick_host_name_from_backend_address = true
      }
    }

    frontend_ports = {
      example_frontend_port = {
        name = "example-frontend-port"
        port = 80
      }
    }

    http_listeners = {
      example_listener = {
        name               = "example-listener"
        frontend_port_name = "example-frontend-port"
      }
    }

    request_routing_rules = {
      example_rule = {
        name                       = "example-rule"
        rule_type                  = "Basic"
        http_listener_name         = "example-listener"
        backend_address_pool_name  = "example-backend-pool"
        backend_http_settings_name = "example-https-settings"
        priority                   = 100
      }
    }
  }
  bastion_definition = {
  }
  container_app_environment_definition = {
    enable_diagnostic_settings = false
  }
  enable_telemetry           = var.enable_telemetry
  flag_platform_landing_zone = false
  genai_container_registry_definition = {
    enable_diagnostic_settings = false
  }
  genai_cosmosdb_definition = {
    enable_diagnostic_settings = false
    consistency_level          = "Session"
  }
  genai_key_vault_definition = {
    #this is for AVM testing purposes only. Doing this as we don't have an easy for the test runner to be privately connected for testing.
    public_network_access_enabled = true
    network_acls = {
      bypass   = "AzureServices"
      ip_rules = ["${data.http.ip.response_body}/32"]
    }
  }
  genai_storage_account_definition = {
    enable_diagnostic_settings = false
  }
  ks_ai_search_definition = {
    enable_diagnostic_settings = false
  }
  private_dns_zones = {
    existing_zones_resource_group_resource_id = module.example_hub.resource_group_resource_id
  }
}
