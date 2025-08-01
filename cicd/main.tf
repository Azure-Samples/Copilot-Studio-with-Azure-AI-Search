locals {
    resource_group_name = "rg-cicd${random_string.name.id}"
    create_network_infrastructure = true
}