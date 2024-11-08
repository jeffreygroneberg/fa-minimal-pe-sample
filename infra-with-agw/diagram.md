# Terraform Infrastructure Diagram

The following diagram represents the components and their relationships in your `infra-with-agw` Terraform scripts:

```mermaid
graph TD
    rg[Resource Group]
    vnet[Virtual Network]
    subnet_pe[Subnet PE]
    subnet_fa[Subnet FA]
    sa[Storage Account]
    pe_blob[Private Endpoint Blob]
    pe_file[Private Endpoint File]
    dns_blob[Private DNS Zone Blob]
    dns_file[Private DNS Zone File]
    dns_link_blob[DNS Zone Link Blob]
    dns_link_file[DNS Zone Link File]
    asp[App Service Plan]
    fa[Function App]
    mi[Managed Identity]
    agw[Application Gateway]
    waf[Web Application Firewall Policy]
    vnet_gw[Gateway Virtual Network]
    vnet_peering[VNet Peering]

    rg --> vnet
    vnet --> subnet_pe
    vnet --> subnet_fa
    rg --> sa
    sa --> pe_blob
    sa --> pe_file
    pe_blob --> subnet_pe
    pe_file --> subnet_pe
    pe_blob --> dns_blob
    pe_file --> dns_file
    dns_blob --> dns_link_blob
    dns_file --> dns_link_file
    dns_link_blob --> vnet
    dns_link_file --> vnet
    rg --> asp
    asp --> fa
    fa --> subnet_fa
    fa --> mi
    mi --> sa
    rg --> agw
    agw --> waf
    agw --> fa
    vnet --> vnet_peering --> vnet_gw