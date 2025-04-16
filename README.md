# azure-image-browser

This repository contains a PowerShell script designed to simplify the process of discovering and selecting Azure VM images. The script provides an interactive interface for browsing available images, filtering by various criteria, and generating a detailed Markdown report of the selected image.

## Features

- Browse Azure VM images interactively by publishers, offers, SKUs, and versions.
- Filter publishers by name or limit results to Microsoft publishers.
- Generate a detailed Markdown report of the selected image, including metadata and best practices.
- Supports pagination for large datasets.
- Provides Azure CLI and Bicep examples for deploying the selected image.

## Prerequisites

- **Azure CLI**: Ensure the Azure CLI is installed and authenticated (`az login`).
- **PowerShell**: The script requires PowerShell Core (`pwsh`) to run.

## Usage

Run the script with the following command:

```powershell
.\Browse-VmImages.ps1 -location <region> -pageSize <number> -microsoftOnly <true|false> -searchPublisher <publisherName>
```

### Parameters

- `-location`: Specifies the Azure region to search for VM images. Defaults to `eastus`.
- `-pageSize`: Number of items to display per page in the interactive list. Defaults to `20`.
- `-microsoftOnly`: If set to `true`, only Microsoft publishers will be displayed. Defaults to `false`.
- `-searchPublisher`: Filter publishers by name. For example, `Canonical`.

### Examples

1. **Browse Microsoft publishers in the `eastus` region**:
   ```powershell
   .\Browse-VmImages.ps1 -location "eastus" -microsoftOnly $true
   ```

2. **Search for publishers matching "Canonical" in the `westus` region**:
   ```powershell
   .\Browse-VmImages.ps1 -location "westus" -searchPublisher "Canonical"
   ```

3. **Display 10 items per page in the `centralus` region**:
   ```powershell
   .\Browse-VmImages.ps1 -location "centralus" -pageSize 10
   ```

## Output

The script generates a detailed Markdown report of the selected image, including:

- Publisher, offer, SKU, and version details.
- Metadata such as OS type, architecture, and security features.
- Azure CLI and Bicep examples for deploying the image.

The report is saved in the script's directory with a filename like `azure-image-<publisher>-<offer>-<sku>-<date>.md`.

## Notes

- Use the `Set-PSDebug -Trace 1` command to enable debugging for troubleshooting.
- The script ensures that the Azure CLI is installed and authenticated before proceeding.

## Links

- Author: Reid Patrick  
  🧙 Kelomai - Command the Cloud  
  [Kelomai.io](https://kelomai.io)  
  [GitHub Repository](https://github.com/kelomai/azure-image-browser)
