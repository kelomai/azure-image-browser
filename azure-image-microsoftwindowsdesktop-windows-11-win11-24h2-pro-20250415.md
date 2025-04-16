# Azure VM Image Selection
Here's your image 📀 thanks to 🧙 [Kelomai](https://kelomai.io) 🚀
<br>
Report Date: 04/15/2025 20:31:09
<br>
Region: EASTUS

## Image Reference
| Property | Value |
|----------|-------|
| Publisher | MicrosoftWindowsDesktop |
| Offer | windows-11 |
| SKU | win11-24h2-pro |
| Latest Version | 26100.3775.250406 |
| OS Type | Windows |
| Hyper-V Generation | V2 |
| Architecture | x64 |
| Image State | Active |
| Security Type | TrustedLaunchAndConfidentialVmSupported |
| Accelerated Networking | True |
| Disk Controller Types | SCSI, NVMe |
| Hibernate Support | True |
| Automatic OS Upgrade Supported | False |
| Disallowed VM Disk Type | Unmanaged |
| Data Disk Images Available | 0 |

## Quick URI Reference
```
MicrosoftWindowsDesktop:windows-11:win11-24h2-pro:latest
```

## Image Versions
| Version | Status |
|---------|--------|
| 26100.2605.241207 | Available |
 | 26100.2894.250113 | Available |
 | 26100.3194.250210 | Available |
 | 26100.3459.250221 | Available |
 | 26100.3476.250306 | Available |
 | 26100.3775.250406 | Available |


## Image Metadata

``` json
{
  "architecture": "x64",
  "automaticOSUpgradeProperties": {
    "automaticOSUpgradeSupported": false
  },
  "dataDiskImages": [],
  "disallowed": {
    "vmDiskType": "Unmanaged"
  },
  "features": [
    {
      "name": "SecurityType",
      "value": "TrustedLaunchAndConfidentialVmSupported"
    },
    {
      "name": "IsAcceleratedNetworkSupported",
      "value": "True"
    },
    {
      "name": "DiskControllerTypes",
      "value": "SCSI, NVMe"
    },
    {
      "name": "IsHibernateSupported",
      "value": "True"
    }
  ],
  "hyperVGeneration": "V2",
  "id": "/Subscriptions/6356d509-cdce-4a30-922d-ff7346a15a65/Providers/Microsoft.Compute/Locations/eastus/Publishers/MicrosoftWindowsDesktop/ArtifactTypes/VMImage/Offers/windows-11/Skus/win11-24h2-pro/Versions/26100.3775.250406",
  "imageDeprecationStatus": {
    "imageState": "Active"
  },
  "location": "eastus",
  "name": "26100.3775.250406",
  "osDiskImage": {
    "operatingSystem": "Windows"
  },
  "publisher": "MicrosoftWindowsDesktop",
  "offer": "windows-11",
  "sku": "win11-24h2-pro",
  "version": "26100.3775.250406",
  "SecurityType": "TrustedLaunchAndConfidentialVmSupported",
  "acceleratedNetworking": "True",
  "diskControllerTypes": "SCSI, NVMe",
  "hibernateSupport": "True"
}
```
## Bicep Example

``` yaml
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4als_v6'  // Choose appropriate size
    }
    storageProfile: {
      imageReference: { //Use the image metadata here
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'  // For production workloads
        }
      }
    }
    // Other required properties not shown
  }
}
```

## Azure CLI Example

``` bash
az vm create \
  --resource-group myResourceGroup \
  --name myVM \
  --image MicrosoftWindowsDesktop:windows-11:win11-24h2-pro:latest \
  --admin-username azureuser \
  --public-ip-sku Standard \
  --size Standard_D4als_v6
```

## Azure Best Practices
- Use the latest version of the image
- Use the latest generation of the VM
- Use Premium_LRS or Premium_ZRS storage for production workloads
- Choose a VM size appropriate for your workload
- Consider using Availability Zones for high availability
- Apply proper tagging for resource management
- For windows VMs, use an admin password that meets complexity requirements
- For Linux VMs, use SSH key authentication instead of passwords
