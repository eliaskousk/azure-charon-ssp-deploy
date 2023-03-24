// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

// This template is used as a module from the main.bicep template. 
// The module contains a template to create network resources.
targetScope = 'resourceGroup'

//
// Parameters
//

@description('Location of all resources')
param location string = resourceGroup().location

@description('Prefix for all names')
param prefix string

@description('Tags for all resources')
param tags object = {
  tag1: 'tag-value-1'
  tag2: 'tag-value-2'
}

@description('The Charon SSP emulator version')
@allowed([
  'Charon-SSP-Latest'
  // 'Charon-SSP-5.4.3'
])
param charonVersion string = 'Charon-SSP-Latest'

@description('Admin Username for VMs')
param adminUsername string 

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH key or password for the VMs. SSH key is recommended')
@secure()
param adminPasswordOrKey string

@description('Number of Emulator Instances')
param numberOfEmulatorInstances int = 2

@description('Size of the Emulator Host VMs')
param vmSizeEmulatorHost string = 'Standard_F2s_v2'

@description('Size of the License Server VM')
param vmSizeLicenseServer string = 'Standard_B2s'

@description('Size of the Manager VM')
param vmSizeManager string = 'Standard_B2s'

@description('Storage Type for Vhds')
param storageAccountType string = 'Standard_LRS'

@description('Virtual Network CIDR Address Range')
param virtualNetworkAddressRange string = '10.0.0.0/16'

@description('Subnet CIDR Address Range')
param subnetAddressRange string = '10.0.0.0/24'

@description('Security Type of the Virtual Machine.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'TrustedLaunch'

//
// Variables
//

var charonImageReference = {
  'Charon-SSP-Latest': {
    publisher: 'stromasys'
    offer: 'charon-ssp-ve'
    sku: 'charon-ssp-with-ve-license'
    version: 'latest'
  }
  // 'Charon-SSP-5.4.3': {
  //   publisher: 'stromasys'
  //   offer: 'charon-ssp-ve'
  //   sku: 'charon-ssp-with-ve-license'
  //   version: '5.4.3'
  // }
}

var charonPlan = {
  name: 'charon-ssp-with-ve-license'
  publisher: 'stromasys'
  product: 'charon-ssp-ve'
}

@description('Name of the Virtual Network')
var virtualNetworkName = '${prefix}-virtual-network'

@description('Name of the Subnet')
var subnetName = '${prefix}-subnet'

@description('Name of the Network Security Group')
var networkSecurityGroupName = '${prefix}-security-group'

@description('Prefix to use for VM names')
var vmNamePrefix = '${prefix}-vm'

@description('Prefix to use for Network Interface names')
var networkInterfaceNamePrefix = '${prefix}-nic'

@description('Prefix to use for Public IP names')
var publicIPAddressNamePrefix = '${prefix}-public-ip'

@description('Loab Balancer name')
var loadBalancerName = '${prefix}-load-balancer'

@description('Availability Set name')
var availabilitySetName = '${prefix}-availability-set'

@description('Unique DNS Name for the Public IP used to access the VMs')
var dnsLabelPrefix = toLower('${vmNamePrefix}-${uniqueString(resourceGroup().id)}')

@description('Storage Account name')
var storageAccountName = uniqueString(resourceGroup().id)

@description('Linux Configuration')
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

@description('Security Profile')
var securityProfile = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}

//
// Storage Account for all VMs
//

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

//
// Availability Set for all VMs
//

resource availabilitySet 'Microsoft.Compute/availabilitySets@2021-11-01' = {
  name: availabilitySetName
  location: location
  tags: tags
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: 2
    platformFaultDomainCount: 2
  }
}

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
// Load Balancer
//

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: loadBalancerName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
        name: 'LoadBalancerFrontend'
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPool1'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadBalancerName, 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'lbprobe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
        name: 'lbrule'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'lbprobe'
      }
    ]
  }
}

//
// Network Security Group for all VMs (Emulator Hosts, Virtual Server and Manager)
//

resource networkSecurityGroupMain 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${networkSecurityGroupName}-main'
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

//
// Network Security Group for Emulator Guests
//

resource networkSecurityGroupGuest 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${networkSecurityGroupName}-guest'
  location: location
  properties: {
    securityRules: [
      {
        name: 'HTTP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

//
// Public IPs for Emulator Hosts
//

resource publicIPAddressHost 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numberOfEmulatorInstances): {
  name: '${publicIPAddressNamePrefix}-host-${i}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'host-${i}-${dnsLabelPrefix}'
    }
    idleTimeoutInMinutes: 4
  }
}]

//
// Public IPs for Emulator Guests
//

resource publicIPAddressGuest 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numberOfEmulatorInstances): {
  name: '${publicIPAddressNamePrefix}-guest-${i}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'guest-${i}-${dnsLabelPrefix}'
    }
    idleTimeoutInMinutes: 4
  }
}]

//
// Public IPs for License Server
//

resource publicIPAddressLicenseServer 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${publicIPAddressNamePrefix}-license-server'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'license-server-${dnsLabelPrefix}'
    }
    idleTimeoutInMinutes: 4
  }
}

//
// Public IPs for Manager
//

resource publicIPAddressManager 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${publicIPAddressNamePrefix}-manager'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'manager-${dnsLabelPrefix}'
    }
    idleTimeoutInMinutes: 4
  }
}

//
// Network Interfaces for Emulator Host (Linux)
//

resource networkInterfaceHost 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, numberOfEmulatorInstances): {
  name: '${networkInterfaceNamePrefix}-host-${i}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressHost[i].id
          }
          // loadBalancerBackendAddressPools: [
          //   {
          //     id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
          //   }
          // ]
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupMain.id
    }
  }
  // dependsOn: [
  //   loadBalancer
  // ]
}]

//
// Network Interfaces for Emulator Guest (Solaris)
//

resource networkInterfaceGuest 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, numberOfEmulatorInstances): {
  name: '${networkInterfaceNamePrefix}-guest-${i}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressGuest[i].id
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'BackendPool1')
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupGuest.id
    }
  }
  dependsOn: [
    loadBalancer
  ]
}]

//
// Network Interface for VE License Server
//

resource networkInterfaceLicenseServer 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${networkInterfaceNamePrefix}-license-server'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressLicenseServer.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupMain.id
    }
  }
}

//
// Network Interface for Manager
//

resource networkInterfaceManager 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${networkInterfaceNamePrefix}-manager'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddressManager.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupMain.id
    }
  }
}

//
// Charon SSP Emulator Host VMs
//

resource vmEmulator 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, numberOfEmulatorInstances): {
  name: '${vmNamePrefix}-host-${i}'
  location: location
  tags: tags
  plan: charonPlan
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSizeEmulatorHost
    }
    osProfile: {
      computerName: '${vmNamePrefix}-host-${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfile : null)
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      imageReference: charonImageReference[charonVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceHost[i].id
          properties: {
            primary: true
          }
        }, {
          id: networkInterfaceGuest[i].id
          properties: {
            primary: false
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}]

//
// Charon VE License Server VM
//

resource vmLicenseServer 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: '${vmNamePrefix}-license-server'
  location: location
  tags: tags
  plan: charonPlan
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSizeLicenseServer
    }
    osProfile: {
      computerName: '${vmNamePrefix}-license-server'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfile : null)
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      imageReference: charonImageReference[charonVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceLicenseServer.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

//
// Charon Manager VM
//

resource vmManager 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: '${vmNamePrefix}-manager'
  location: location
  tags: tags
  plan: charonPlan
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSizeManager
    }
    osProfile: {
      computerName: '${vmNamePrefix}-manager'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfile : null)
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      imageReference: charonImageReference[charonVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceManager.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

output adminUsername string = adminUsername

output emulatorHostInfo array = [for i in range(0, numberOfEmulatorInstances): {
  fqdn: publicIPAddressHost[i].properties.dnsSettings.fqdn
  ssh: 'ssh ${adminUsername}@${publicIPAddressHost[i].properties.dnsSettings.fqdn}'
}]

output emulatorGuestInfo array = [for i in range(0, numberOfEmulatorInstances): {
  fqdn: publicIPAddressGuest[i].properties.dnsSettings.fqdn
  ssh: 'ssh ${adminUsername}@${publicIPAddressGuest[i].properties.dnsSettings.fqdn}'
}]

output licenseServerInfo object = {
  fqdn: publicIPAddressLicenseServer.properties.dnsSettings.fqdn
  ssh: 'ssh ${adminUsername}@${publicIPAddressLicenseServer.properties.dnsSettings.fqdn}'
}

output managerInfo object = {
  fqdn: publicIPAddressManager.properties.dnsSettings.fqdn
  ssh: 'ssh ${adminUsername}@${publicIPAddressManager.properties.dnsSettings.fqdn}'
}
