targetScope = 'resourceGroup'

//
// Parameters
//

@description('Location of all resources')
param location string = resourceGroup().location

@description('Prefix for all names')
param prefix string = 'test'

@description('Virtual Network CIDR Address Range')
param virtualNetworkAddressRange string = '10.0.0.0/16'

@description('Subnet CIDR Address Range')
param subnetAddressRange string = '10.0.0.0/24'

@description('Admin Username for VMs')
param adminUsername string = 'sshuser'

// @description('Security Type of the Virtual Machine.')
// @allowed([
//   'Standard'
//   'TrustedLaunch'
// ])
// param securityType string = 'Standard'

//
// Variables
//

@description('Name of the Virtual Network')
var virtualNetworkName = '${prefix}-virtual-network'

@description('Name of the Subnet')
var subnetName = '${prefix}-subnet'

// @description('Number of redundant resources for HA')
// var numberOfResourcesHA = 2

// @description('Prefix to use for Public IP names')
// var publicIPAddressNamePrefix = '${prefix}-public-ip'

// @description('Unique DNS Name for the Public IP used to access the VMs')
// var dnsLabelPrefix = toLower('${prefix}-vm-${uniqueString(resourceGroup().id)}')

// @description('Security Profile')
// var securityProfile = {
//   uefiSettings: {
//     secureBootEnabled: true
//     vTpmEnabled: true
//   }
//   securityType: securityType
// }

//
// Virtual Network and Subnet for all VMs
//

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  parent: virtualNetwork
  name: subnetName
  properties: {
    addressPrefix: subnetAddressRange
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

//
// Public IPs for Emulator Hosts
//

// resource publicIPAddressHost 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
//   name: '${publicIPAddressNamePrefix}-host-${i}'
//   location: location
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//     publicIPAddressVersion: 'IPv4'
//     dnsSettings: {
//       domainNameLabel: 'host-${i}-${dnsLabelPrefix}'
//     }
//     idleTimeoutInMinutes: 4
//   }
// }]

//
// Public IPs for Emulator Guests
//

// resource publicIPAddressGuest 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
//   name: '${publicIPAddressNamePrefix}-guest-${i}'
//   location: location
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//     publicIPAddressVersion: 'IPv4'
//     dnsSettings: {
//       domainNameLabel: 'guest-${i}-${dnsLabelPrefix}'
//     }
//     idleTimeoutInMinutes: 4
//   }
// }]

//
// Public IPs for License Server
//

// resource publicIPAddressLicenseServer 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
//   name: '${publicIPAddressNamePrefix}-license-server-${i}'
//   location: location
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//     publicIPAddressVersion: 'IPv4'
//     dnsSettings: {
//       domainNameLabel: 'license-server-${i}-${dnsLabelPrefix}'
//     }
//     idleTimeoutInMinutes: 4
//   }
// }]

//
// Public IPs for Manager
//

// resource publicIPAddressManager 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
//   name: '${publicIPAddressNamePrefix}-manager-${i}'
//   location: location
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//     publicIPAddressVersion: 'IPv4'
//     dnsSettings: {
//       domainNameLabel: 'manager-${i}-${dnsLabelPrefix}'
//     }
//     idleTimeoutInMinutes: 4
//   }
// }]

output adminUsername string = adminUsername

output subnetId string = subnet.id

// output emulatorHostInfo array = [for i in range(0, numberOfResourcesHA): {
//   fqdn: publicIPAddressHost[i].properties.dnsSettings.fqdn
//   ssh: 'ssh ${adminUsername}@${publicIPAddressHost[i].properties.dnsSettings.fqdn}'
// }]

// output emulatorGuestInfo array = [for i in range(0, numberOfResourcesHA): {
//   fqdn: publicIPAddressGuest[i].properties.dnsSettings.fqdn
//   ssh: 'ssh ${adminUsername}@${publicIPAddressGuest[i].properties.dnsSettings.fqdn}'
// }]

// output licenseServerInfo array = [for i in range(0, numberOfResourcesHA): {
//   fqdn: publicIPAddressLicenseServer[i].properties.dnsSettings.fqdn
//   ssh: 'ssh ${adminUsername}@${publicIPAddressLicenseServer[i].properties.dnsSettings.fqdn}'
// }]

// output managerInfo array = [for i in range(0, numberOfResourcesHA): {
//   fqdn: publicIPAddressManager[i].properties.dnsSettings.fqdn
//   ssh: 'ssh ${adminUsername}@${publicIPAddressManager[i].properties.dnsSettings.fqdn}'
// }]
