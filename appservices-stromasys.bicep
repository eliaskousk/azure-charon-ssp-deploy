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
param prefix string = 'test'

@description('Tags for all resources')
param tags object = {
  tag1: 'tag-value-1'
}

@description('Size of the Emulator Host VMs')
param vmSizeEmulatorHost string = 'Standard_F8s_v2'

@description('Size of the License Server VM')
param vmSizeLicenseServer string = 'Standard_B2s'

@description('Size of the Manager VM')
param vmSizeManager string = 'Standard_B2s'

@description('Storage Type for Vhds')
param storageAccountType string = 'Standard_LRS'

@description('Id of the subnet')
param subnetId string = ''

@description('Admin Username for VMs')
param adminUsername string = 'sshuser'

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH key or password for the VMs. SSH key is recommended')
@secure()
param adminPasswordOrKey string

//
// ========================================================
//

//
// Variables
//

var charonImageReference = {
  publisher: 'stromasys'
  offer: 'charon-ssp-ve'
  sku: 'charon-ssp-with-ve-license'
  version: 'latest'
}

var charonPlan = {
  name: 'charon-ssp-with-ve-license'
  publisher: 'stromasys'
  product: 'charon-ssp-ve'
}

@description('Number of redundant resources for HA')
var numberOfResourcesHA = 2

@description('Availability Set name')
var availabilitySetName = '${prefix}-availability-set'

@description('Loab Balancer name')
var loadBalancerName = '${prefix}-load-balancer'

@description('Name of the Network Security Group')
var networkSecurityGroupName = '${prefix}-security-group'

@description('Prefix to use for Network Interface names')
var networkInterfaceNamePrefix = '${prefix}-nic'

@description('Prefix to use for VM names')
var vmNamePrefix = '${prefix}-vm'

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
// Availability Sets for all VMs (Emulator Hosts, Virtual Server and Manager)
//

resource availabilitySet 'Microsoft.Compute/availabilitySets@2021-11-01' = [for i in range(0, 3): {
  name: '${availabilitySetName}-${i}'
  location: location
  tags: tags
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: numberOfResourcesHA
    platformFaultDomainCount: numberOfResourcesHA
  }
}]

//
// Load Balancer for Emulator Host VMs
//

resource loadBalancerEmulatorHostAndGuest 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: '${loadBalancerName}-emulator-host-and-guest'
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
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
        name: 'LoadBalancerFrontend'
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPoolHostSSH'
      }
      {
        name: 'BackendPoolGuestApp'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', '${loadBalancerName}-emulator-host-and-guest', 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-emulator-host-and-guest', 'BackendPoolHostSSH')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${loadBalancerName}-emulator-host-and-guest', 'LBProbeHostSSH')
          }
          protocol: 'Tcp'
          frontendPort: 22
          backendPort: 22
          idleTimeoutInMinutes: 15
        }
        name: 'LBRuleHostSSH'
      }
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', '${loadBalancerName}-emulator-host-and-guest', 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-emulator-host-and-guest', 'BackendPoolGuestApp')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${loadBalancerName}-emulator-host-and-guest', 'LBProbeGuestApp')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
        name: 'LBRuleGuestApp'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'LBProbeHostSSH'
      }
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'LBProbeGuestApp'
      }
    ]
  }
}

//
// Load Balancer for VE License Server VMs
//

resource loadBalancerLicenseServer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: '${loadBalancerName}-license-server'
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
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
        name: 'LoadBalancerFrontend'
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPoolSSH'
      }
      {
        name: 'BackendPoolLicense'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', '${loadBalancerName}-license-server', 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-license-server', 'BackendPoolSSH')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${loadBalancerName}-license-server', 'LBProbeSSH')
          }
          protocol: 'Tcp'
          frontendPort: 22
          backendPort: 22
          idleTimeoutInMinutes: 15
        }
        name: 'LBRuleSSH'
      }
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', '${loadBalancerName}-license-server', 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-license-server', 'BackendPoolLicense')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${loadBalancerName}-license-server', 'LBProbeLicense')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 15
        }
        name: 'LBRuleLicense'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'LBProbeSSH'
      }
      {
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'LBProbeLicense'
      }
    ]
  }
}

//
// Load Balancer for Manager VMs
//

resource loadBalancerManager 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: '${loadBalancerName}-manager'
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
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
        name: 'LoadBalancerFrontend'
      }
    ]
    backendAddressPools: [
      {
        name: 'BackendPoolSSH'
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', '${loadBalancerName}-manager', 'LoadBalancerFrontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-manager', 'BackendPoolSSH')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', '${loadBalancerName}-manager', 'LBProbeSSH')
          }
          protocol: 'Tcp'
          frontendPort: 22
          backendPort: 22
          idleTimeoutInMinutes: 15
        }
        name: 'LBRuleSSH'
      }
    ]
    probes: [
      {
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: 'LBProbeSSH'
      }
    ]
  }
}

//
// Network Security Group for all VMs (Emulator Hosts, License Server and Manager)
//

resource networkSecurityGroupSSH 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${networkSecurityGroupName}-ssh'
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
// Network Security Group for Emulator Guest App
//

resource networkSecurityGroupGuest 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${networkSecurityGroupName}-emulator-guest'
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
// Network Interfaces for Emulator Host (Linux)
//

resource networkInterfaceEmulatorHost 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${networkInterfaceNamePrefix}-emulator-host-${i}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-emulator-host-and-guest', 'BackendPoolHostSSH')
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupSSH.id
    }
  }
  dependsOn: [
    loadBalancerEmulatorHostAndGuest
  ]
}]

//
// Network Interfaces for Emulator Guest (Solaris)
//

resource networkInterfaceEmulatorGuest 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${networkInterfaceNamePrefix}-emulator-guest-${i}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-emulator-host-and-guest', 'BackendPoolGuestApp')
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
    loadBalancerEmulatorHostAndGuest
  ]
}]

//
// Network Interfaces for VE License Server
//

resource networkInterfaceLicenseServer 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${networkInterfaceNamePrefix}-license-server-${i}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-license-server', 'BackendPoolSSH')
            }
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-license-server', 'BackendPoolLicense')
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupSSH.id
    }
  }
  dependsOn: [
    loadBalancerLicenseServer
  ]
}]

//
// Network Interfaces for Manager
//

resource networkInterfaceManager 'Microsoft.Network/networkInterfaces@2021-05-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${networkInterfaceNamePrefix}-manager-${i}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', '${loadBalancerName}-manager', 'BackendPoolSSH')
            }
          ]
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupSSH.id
    }
  }
  dependsOn: [
    loadBalancerManager
  ]
}]

//
// Charon SSP Emulator Host VMs
//

resource vmEmulator 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${vmNamePrefix}-host-${i}'
  location: location
  tags: tags
  plan: charonPlan
  properties: {
    availabilitySet: {
      id: availabilitySet[0].id
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
    securityProfile: null
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      imageReference: charonImageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceEmulatorHost[i].id
          properties: {
            primary: true
          }
        }, {
          id: networkInterfaceEmulatorGuest[i].id
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
// Charon VE License Server VMs
//

resource vmLicenseServer 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${vmNamePrefix}-license-server-${i}'
  location: location
  tags: tags
  plan: charonPlan
  properties: {
    availabilitySet: {
      id: availabilitySet[1].id
    }
    hardwareProfile: {
      vmSize: vmSizeLicenseServer
    }
    osProfile: {
      computerName: '${vmNamePrefix}-license-server-${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: null
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      imageReference: charonImageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceLicenseServer[i].id
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
// Charon Manager VMs
//

resource vmManager 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, numberOfResourcesHA): {
  name: '${vmNamePrefix}-manager-${i}'
  location: location
  tags: tags
  plan: charonPlan
  properties: {
    availabilitySet: {
      id: availabilitySet[2].id
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
    securityProfile: null
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
      imageReference: charonImageReference
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceManager[i].id
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
