terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.41.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    # purge_soft_delete_on_destroy    = true
    # recover_soft_deleted_key_vaults = true
  }
}

#terraform init -upgrade

resource "azurerm_resource_group" "rg" {
  name     = "${var.name}d"
  location = var.location 
}

#terraform apply


#1) #DEPLOYER UN STORAGE ACCOUNT AVEC TERRAFORM SUR VOTRE RESOURCE GROUP, 

resource "azurerm_storage_account" "storage" {
  name                     = "raphdstorage"
  resource_group_name      = data.azurerm_resource_group.lergdecorentin.name
  location                 = data.azurerm_resource_group.lergdecorentin.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


#Optional : #--> #Azure Storage Explorer, Déployer un conteneur sur votre storage account, générer une clé d'accès. 

#Déployer un Keyvault avec Terraform 


# #DEPLOYER UN KEYVAULT ET DONNER LES DROITS GET SECRET A ENSI

data "azurerm_client_config" "current" {
}

resource "azurerm_key_vault" "keyvault" {
  name                     = "rapdkeyvault"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id #ID D ACTIVE DIRECTORY "fbd5b602-423c-4722-be67-8382bc9dc8fa"
    object_id = data.azurerm_client_config.current.object_id #ID D UN UTILISATEUR "51f50813-c533-4026-bf36-9f9cadb28b5e"

    secret_permissions = [
      "Get",
      "Delete",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set"
    ]
  }
}

# DEPLOYER UN SECRET (MDP) DANS VOTRE KEYVAULT ET ALLEZ LE LIRE GRAPHIQUEMENT 5/10mn

resource "azurerm_key_vault_secret" "secret" {
  name         = "mymdp"
  value        = random_password.passwordsql.result
  key_vault_id = azurerm_key_vault.keyvault.id # = "/subscriptions/556b3479-49e0-4048-ace9-9b100efe5b6d/resourceGroups/raphd/providers/Microsoft.KeyVault/vaults/rapdkeyvault"
}


# Deployer un MSSQL SERVEUR en Terraform avec un mdp sécurisé

resource "azurerm_mssql_server" "sqlsrv" {
  name                         = "raphsqlsrv"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "adminraph"
  administrator_login_password = random_password.passwordsql.result
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = data.azurerm_client_config.current.object_id
  }
}

resource "random_password" "passwordsql" {
  length           = 16
  special          = true
  min_special      = 1
  min_numeric      = 1
  min_lower        = 1
  min_upper        = 1
  override_special = "!"
}

# Déployer sur votre MSSQL Serveur une MSSQL Database --> (General Purpose Serverless, 2Vcore, et qu'elle s'arrête automatiquement à partir de 90mn) 15mn

resource "azurerm_mssql_database" "mydatabase" {
  name                        = "raph-database"
  server_id                   = azurerm_mssql_server.sqlsrv.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                 = 10
  read_scale                  = false
  sku_name                    = "GP_S_Gen5_2"
  zone_redundant              = true
  auto_pause_delay_in_minutes = 90
  min_capacity                = 1
}

#terraform destroy -auto-approve

# DELETE TFSTATE & TFSTATE BACKUP 

# az logout 

# az login



# ensi2@deletoilleprooutlook.onmicrosoft.com

# Salut123! 

# terraform init 
# terraform apply 


# https://github.com/raphaeldeletoille/ensi 


resource "azurerm_virtual_network" "mynetwork" {
  name                = "raph-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
}

resource "azurerm_subnet" "mysubnet" { #0/1/2
  count                = 3
  name                 = "mysubnet-subnet${count.index}" #0/1/2
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.mynetwork.name
  address_prefixes     = ["10.0.${count.index}.0/24"] #0/1/2

  # delegation {
  #   name = "delegation"

  #   service_delegation {
  #     name    = "Microsoft.ContainerInstance/containerGroups"
  #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
  #   }
  # }
}

# terraform fmt 

# INJECTER VOTRE KEYVAULT DANS VOTRE SUBNET 2 

# PRIVATE ENDPOINT (CARTE RESEAU) 

# Private Service Connection (LIER LA RESOURCE A LA CARTE RESEAU)

resource "azurerm_private_endpoint" "networkcard" {
  name                = "raph-kv-network-card"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.mysubnet[2].id

  private_service_connection {
    name                           = "link-raph-keyvault"
    private_connection_resource_id = azurerm_key_vault.keyvault.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

resource "azurerm_public_ip" "mypublicip" {
  name                = "raph-ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "myvmcard" {
  name                = "myvmcard"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mysubnet[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mypublicip.id
  }
}

resource "azurerm_windows_virtual_machine" "myvm" {
  name                = "raph-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.myvmcard.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

# Deployer une Virtual Machine en Terraform (Windows Server ou Ubuntu) et la relier à votre subnet 0

# Deployer une IP Public en Terraform pour vous connecter à votre VM

# VM_Size = Standard_B2s

# 1ere Solution : VPN 
# 2eme Solution (Azure) : Bastion 
# 3eme Solution : Ip public 

# 13h45 V 

# 1) Recoltez les logs de vos resources (IP Forbiddent)
# 2) Monitorez (Analyse) (Quelle fréquence)
# 3) Alerte (Si + de 10 Forbiden, recevoir un appel téléphonique) --> Créer un Action Group, Créer sa Règle d'alerting. 

# SMS/ APPEL / EMAIL 


# En Terraform : 

#1ere etape : Créer un Log Analytics Workspace 

#2eme etape : Envoyer les logs & metrics de votre keyvault vers votre Log Analytics (Diagnostic Settings)


resource "azurerm_log_analytics_workspace" "myloganalytics" {
  name                = "raph-log-analytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "sendkvlogs" {
  name                       = "sendkvlogs"
  target_resource_id         = azurerm_key_vault.keyvault.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.leloganalyticsdeleo.workspace_id

  enabled_log {
    category = "AuditEvent"

    retention_policy {
      enabled = false
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

#Datasource : Permet de récupérer des informations et utiliser une resource déjà existante en dehors de votre code. 

#Vous allez déposer un secret dans mon keyvault (via un datasource). 
#Essayez d'utiliser des variables 


