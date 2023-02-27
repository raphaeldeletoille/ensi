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
  name     = "raphd"
  location = "West Europe"
}

#terraform apply


#1) #DEPLOYER UN STORAGE ACCOUNT AVEC TERRAFORM SUR VOTRE RESOURCE GROUP, 

resource "azurerm_storage_account" "storage" {
  name                     = "raphdstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
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
  name           = "raph-database"
  server_id      = azurerm_mssql_server.sqlsrv.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 10
  read_scale     = false
  sku_name       = "GP_S_Gen5_2"
  zone_redundant = true
  auto_pause_delay_in_minutes = 90
  min_capacity = 1
}

#terraform destroy -auto-approve

# DELETE TFSTATE & TFSTATE BACKUP 

# az logout 

# az login



# ensi2@deletoilleprooutlook.onmicrosoft.com

# Salut123! 

# terraform init 
# terraform apply 






