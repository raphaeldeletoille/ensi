# Exemple Datasource :

# data "azurerm_resource_group" "rgbilly" {
#   name = "Billy"
# }

# data "azurerm_client_config" "current" {
# }

data "azurerm_log_analytics_workspace" "leloganalyticsdeleo" {
  name                = "loganaleo"
  resource_group_name = "leollc"
}

data "azurerm_resource_group" "lergdecorentin" {
  name = "corentina"
}

output "log_analytics_workspace_id" {
  value = data.azurerm_log_analytics_workspace.leloganalyticsdeleo.primary_shared_key
}

