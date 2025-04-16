#! /usr/bin/env pwsh
<#
.SYNOPSIS
Browse and select Azure VM images interactively using the Azure CLI.

.DESCRIPTION
This script provides an interactive way to browse and select Azure VM images 
available in a specified Azure region. It allows users to filter publishers, 
offers, SKUs, and versions, and generates a detailed report of the selected image.

.PARAMETER location
Specifies the Azure region to search for VM images. Defaults to "southcentralus".

.PARAMETER pageSize
Specifies the number of items to display per page in the interactive list. Defaults to 20.

.PARAMETER microsoftOnly
If set to $true, only Microsoft publishers will be displayed. Defaults to $false.

.PARAMETER searchPublisher
Specifies a search term to filter publishers by name. If provided, only publishers 
matching the search term will be displayed.

.FUNCTION Get-MicrosoftPublishers
Returns a static list of commonly used Microsoft publishers.

.FUNCTION Get-CommonPublishers
Returns a static list of commonly used non-Microsoft publishers.

.FUNCTION Show-PaginatedList
Displays an interactive, paginated list of items, allowing users to navigate, filter, 
and select an item.

.FUNCTION Get-AzureVMPublishers
Fetches a list of VM image publishers available in the specified Azure region.

.FUNCTION Get-AzureVMOffers
Fetches a list of VM image offers for a specified publisher in the specified Azure region.

.FUNCTION Get-AzureVMSkus
Fetches a list of VM image SKUs for a specified publisher and offer in the specified Azure region.

.FUNCTION Get-AzureVMImageVersions
Fetches a list of VM image versions for a specified publisher, offer, and SKU in the specified Azure region.

.FUNCTION Get-ImageDetail
Fetches detailed information about a specific VM image, including metadata and features.

.EXAMPLE
.\Browse-VmImages.ps1 -location "eastus" -pageSize 10 -microsoftOnly $true

This example runs the script to browse Azure VM images in the "eastus" region, 
displaying 10 items per page and limiting results to Microsoft publishers.

.EXAMPLE
.\Browse-VmImages.ps1 -location "westus" -searchPublisher "Canonical"

This example runs the script to browse Azure VM images in the "westus" region, 
filtering publishers to those matching "Canonical".

.NOTES
- Requires the Azure CLI to be installed and authenticated.
- The script generates a detailed report of the selected image in Markdown format.
- Use the `Set-PSDebug -Trace 1` command to enable debugging for troubleshooting.

.LINK
Author: Reid Patrick  
🧙 Kelomai - Command the Cloud  
https://kelomai.io  
https://github.com/kelomai/azure-image-browser  
#>

param (
    [Parameter(Mandatory = $false)][string]$location = "eastus",
    [Parameter(Mandatory = $false)][int]$pageSize = 20,
    [Parameter(Mandatory = $false)][bool]$microsoftOnly = $false,
    [Parameter(Mandatory = $false)][string]$searchPublisher = ""
)

# **Kelomai - Script Header Start**
# Welcome to Kelomai
Clear-Host
Write-Host -ForegroundColor DarkGray "--------------------------" 
Write-Host -ForegroundColor DarkGray "Welcome 👋 to 🧙 Kelomai 🚀"
Write-Host -ForegroundColor DarkGray "    https://kelomai.io    "
Write-Host -ForegroundColor DarkGray "--------------------------"

# Set strict mode and error action preference
$ErrorActionPreference = "Stop"
Set-PSDebug -Trace 0 # Set to 1 for debugging
Set-StrictMode -Version 3.0

# Ensure Azure CLI is installed and logged in
if (-not (Get-Command "az" -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' })) {
    Write-Host "Error: Azure CLI is not installed or not found in the system PATH. Please install it and ensure it is accessible before running this script." -ForegroundColor Red
    exit 1
}

if (-not (az account show --query "id" --output tsv 2>$null)) {
    Write-Host "Error: You are not logged in to Azure CLI. Please log in using 'az login'." -ForegroundColor Red
    exit 1
}

# Display the current subscription in json format
Write-Host -ForegroundColor Yellow "Current Azure subscription details:"
az account show --output jsonc

# Ask the user if they want to continue using this subscription
Write-Host -ForegroundColor Cyan "Do you want to continue using this subscription? (yes/no) " -NoNewline
$continue = Read-Host

if ($continue -notmatch "^(yes|y)$") {
    Write-Host -ForegroundColor Red "Exiting the script as per user request."
    exit 0
}
Clear-Host
# **Kelomai - Script Header End**

# Functions
function Get-MicrosoftPublishers {
    # Return a static list of the most commonly used Microsoft publishers
    $microsoftPublishers = @(
        [PSCustomObject]@{ name = 'MicrosoftWindowsServer' },
        [PSCustomObject]@{ name = 'MicrosoftWindowsDesktop' },
        [PSCustomObject]@{ name = 'MicrosoftSQLServer' },
        [PSCustomObject]@{ name = 'MicrosoftVisualStudio' }
    )
    
    return $microsoftPublishers | Sort-Object -Property name
}

function Get-CommonPublishers {
    # Return a list of commonly used non-Microsoft publishers
    $commonPublishers = @(
        [PSCustomObject]@{ name = 'bitnami' },
        [PSCustomObject]@{ name = 'Canonical' },
        [PSCustomObject]@{ name = 'center-for-internet-security-inc' },
        [PSCustomObject]@{ name = 'checkpoint' },
        [PSCustomObject]@{ name = 'Debian' },
        [PSCustomObject]@{ name = 'docker' },
        [PSCustomObject]@{ name = 'fortinet' },
        [PSCustomObject]@{ name = 'OpenLogic' },
        [PSCustomObject]@{ name = 'Oracle' },
        [PSCustomObject]@{ name = 'paloaltonetworks' },
        [PSCustomObject]@{ name = 'RedHat' },
        [PSCustomObject]@{ name = 'SUSE' },
        [PSCustomObject]@{ name = 'vmware' }
    )
    
    return $commonPublishers | Sort-Object -Property name
}

function Show-PaginatedList {
    param (
        [Parameter(Mandatory = $true)][array]$itemList,
        [Parameter(Mandatory = $true)][string]$title,
        [Parameter(Mandatory = $false)][int]$pageSize = 20,
        [Parameter(Mandatory = $false)][string]$filter = ""
    )

    # If filter is provided, filter the list before pagination
    if (![string]::IsNullOrEmpty($filter)) {
        $itemList = $itemList | Where-Object { 
            # Fixed property checking
            if ($_.PSObject.Properties.Match('offer').Count) { $_.offer -like "*$filter*" }
            elseif ($_.PSObject.Properties.Match('sku').Count) { $_.sku -like "*$filter*" }
            else { $_.name -like "*$filter*" }
        }
    }

    $totalItems = $itemList.Count
    if ($totalItems -eq 0) {
        Write-Host "No items matched your filter criteria." -ForegroundColor Yellow
        return $null
    }
    
    $totalPages = [Math]::Ceiling($totalItems / $pageSize)
    $currentPage = 1

    while ($true) {
        Clear-Host
        Write-Host "$title (Page $currentPage of $totalPages)" -ForegroundColor Cyan
        if (![string]::IsNullOrEmpty($filter)) {
            Write-Host "Filtering items by: '$filter'" -ForegroundColor Yellow
        }
        Write-Host "------------------------------------------------" -ForegroundColor DarkGray

        $startIndex = ($currentPage - 1) * $pageSize
        $endIndex = [Math]::Min($startIndex + $pageSize - 1, $totalItems - 1)

        for ($i = $startIndex; $i -le $endIndex; $i++) {
            $index = $i + 1
            # Fixed property checking
            if ($itemList[$i].PSObject.Properties.Match('offer').Count) {
                # Display offer item format
                Write-Host "$index. $($itemList[$i].offer)" -ForegroundColor Yellow
            } 
            elseif ($itemList[$i].PSObject.Properties.Match('sku').Count) {
                # Display sku item format
                Write-Host "$index. $($itemList[$i].sku)" -ForegroundColor Yellow
            }
            else {
                # Display publisher item format
                Write-Host "$index. $($itemList[$i].name)" -ForegroundColor Yellow
            }
        }

        Write-Host "------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "Navigation: [N]ext page | [P]revious page | [S]elect by number | [F]ilter list | [Q]uit" -ForegroundColor DarkGray
        Write-Host "Or enter a number directly to select that item" -ForegroundColor Green
        
        $input = Read-Host "Enter your choice"

        # Handle direct numeric input as selection
        if ([int]::TryParse($input, [ref]$null)) {
            $itemIndex = [int]$input - 1  # Convert to zero-based index
            
            # Check if the index is within range
            if ($itemIndex -ge 0 -and $itemIndex -lt $totalItems) {
                return $itemList[$itemIndex]
            }
            else {
                Write-Host "Invalid selection. Please enter a number between 1 and $totalItems" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        # Handle navigation commands
        elseif ($input -eq "n" -or $input -eq "N") {
            if ($currentPage -lt $totalPages) {
                $currentPage++
            }
            else {
                Write-Host "Already on the last page" -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
        elseif ($input -eq "p" -or $input -eq "P") {
            if ($currentPage -gt 1) {
                $currentPage--
            }
            else {
                Write-Host "Already on the first page" -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }
        elseif ($input -eq "f" -or $input -eq "F") {
            $newFilter = Read-Host "Enter filter text (leave empty to clear filter)"
            return Show-PaginatedList -itemList $itemList -title $title -pageSize $pageSize -filter $newFilter
        }
        elseif ($input -eq "q" -or $input -eq "Q") {
            return $null
        }
        elseif ($input -eq "s" -or $input -eq "S") {
            $itemNumber = Read-Host "Enter the item number to select (1-$totalItems)"
            $itemIndex = 0
            if ([int]::TryParse($itemNumber, [ref]$itemIndex) -and $itemIndex -ge 1 -and $itemIndex -le $totalItems) {
                return $itemList[$itemIndex - 1]
            }
            else {
                Write-Host "Invalid selection. Please enter a number between 1 and $totalItems" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
        else {
            Write-Host "Invalid input. Press any key to continue..." -ForegroundColor Red
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

function Get-AzureVMPublishers {
    param (
        [string]$location
    )
    
    Write-Host "Fetching VM image publishers for $location..." -ForegroundColor Cyan

    try {
        # Use --query to filter results server-side
        $publishers = az vm image list-publishers -l $location --query "[].{name:name}" -o json | ConvertFrom-Json
        # Sort alphabetically by name
        return $publishers | Sort-Object -Property name
    }
    catch {
        Write-Host "Error fetching VM image publishers: $_" -ForegroundColor Red
        return $null
    }
}

function Get-AzureVMOffers {
    param (
        [string]$location,
        [string]$publisher
    )
    
    Write-Host "Fetching VM image offers for publisher $publisher..." -ForegroundColor Cyan

    try {
        # Use --query to filter results server-side
        $offers = az vm image list-offers -l $location -p $publisher --query "[].{offer:name}" -o json | ConvertFrom-Json
        # Sort alphabetically by offer name
        return $offers | Sort-Object -Property offer
    }
    catch {
        Write-Host "Error fetching VM image offers: $_" -ForegroundColor Red
        return $null
    }
}

function Get-AzureVMSkus {
    param (
        [string]$location,
        [string]$publisher,
        [string]$offer
    )
    
    Write-Host "Fetching VM image SKUs for publisher $publisher and offer $offer..." -ForegroundColor Cyan

    try {
        # Use --query to filter results server-side
        $skus = az vm image list-skus -l $location -p $publisher -f $offer --query "[].{sku:name}" -o json | ConvertFrom-Json
        # Sort alphabetically by sku name
        return $skus | Sort-Object -Property sku
    }
    catch {
        Write-Host "Error fetching VM image SKUs: $_" -ForegroundColor Red
        return $null
    }
}

function Get-AzureVMImageVersions {
    param (
        [string]$location,
        [string]$publisher,
        [string]$offer,
        [string]$sku
    )
    
    Write-Host "Fetching VM image versions for publisher $publisher, offer $offer, and SKU $sku..." -ForegroundColor Cyan

    try {
        # Use selective queries to improve performance
        $versions = az vm image list -l $location -p $publisher -f $offer -s $sku --all --query "[].{version:version}" -o json | ConvertFrom-Json
        # Sort versions properly (not alphabetically)
        return $versions | Sort-Object -Property { 
            # Convert version strings to comparable arrays of integers
            $_.version.Split('.') | ForEach-Object { [int]$_ } 
        }
    }
    catch {
        Write-Host "Error fetching VM image versions: $_" -ForegroundColor Red
        return $null
    }
}

function Get-ImageDetail {
    param (
        [string]$location,
        [string]$publisher,
        [string]$offer,
        [string]$sku,
        [string]$version = "latest"
    )
    
    Write-Host "Fetching detailed image information for ${publisher}:${offer}:${sku}:${version}..." -ForegroundColor Cyan
    try {
        $urn = "${publisher}:${offer}:${sku}:${version}"
        $imageExists = az vm image show --location $location --urn $urn --query "name" -o tsv 2>$null
        if (-not $imageExists) {
            Write-Host "Image not found: $urn in region $location" -ForegroundColor Yellow
            return $null
        }

        $imageDetailJson = az vm image show --location $location --urn $urn -o json
        if (-not $imageDetailJson) {
            Write-Host "Failed to get image details for $urn" -ForegroundColor Yellow
            return $null
        }

        $imageDetail = $imageDetailJson | ConvertFrom-Json

        $imageDetail | Add-Member -NotePropertyName "publisher" -NotePropertyValue $publisher -Force
        $imageDetail | Add-Member -NotePropertyName "offer" -NotePropertyValue $offer -Force
        $imageDetail | Add-Member -NotePropertyName "sku" -NotePropertyValue $sku -Force
        $imageDetail | Add-Member -NotePropertyName "version" -NotePropertyValue $version -Force

        # Features - with enhanced null checking
        if ($null -ne $imageDetail -and $imageDetail.PSObject.Properties.Match('features').Count -gt 0 -and $null -ne $imageDetail.features) {
            foreach ($feature in $imageDetail.features) {
                if ($null -ne $feature -and $feature.PSObject.Properties.Match('name').Count -gt 0 -and $feature.PSObject.Properties.Match('value').Count -gt 0) {
                    switch ($feature.name) {
                        "SecurityType" {
                            Add-Member -InputObject $imageDetail -MemberType NoteProperty -Name "SecurityType" -Value $feature.value -Force
                        }
                        "IsAcceleratedNetworkSupported" {
                            Add-Member -InputObject $imageDetail -MemberType NoteProperty -Name "acceleratedNetworking" -Value $feature.value -Force
                        }
                        "DiskControllerTypes" {
                            Add-Member -InputObject $imageDetail -MemberType NoteProperty -Name "diskControllerTypes" -Value $feature.value -Force
                        }
                        "IsHibernateSupported" {
                            Add-Member -InputObject $imageDetail -MemberType NoteProperty -Name "hibernateSupport" -Value $feature.value -Force
                        }
                        # No default case needed as we're just collecting properties
                    }
                }
            }
        }

        return $imageDetail
    }
    catch {
        Write-Host "Error fetching image details: $_" -ForegroundColor Red
        Write-Host "The image $publisher`:$offer`:$sku`:$version may not be available in region $location" -ForegroundColor Yellow
        Write-Host "Try using a specific version number instead of 'latest'" -ForegroundColor Yellow
        return $null
    }
}

# Main Script
Write-Host "Welcome to the Kelomai 🧙 - Azure VM 📀 Image Browser" -ForegroundColor Magenta
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "This tool will help you find available VM images in Azure for region: $($location.ToUpper())" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

# Step 1: Get publishers
if ($microsoftOnly -eq $true -or $searchPublisher -eq "microsoft") {
    Write-Host "Showing only Microsoft publishers..." -ForegroundColor Yellow
    $publishers = Get-MicrosoftPublishers
    Write-Host "Found $($publishers.Count) Microsoft publishers." -ForegroundColor Green
}
elseif ($searchPublisher -eq "common") {
    Write-Host "Showing commonly used publishers..." -ForegroundColor Yellow
    $publishers = Get-CommonPublishers
    Write-Host "Found $($publishers.Count) common publishers." -ForegroundColor Green
}
else {
    # Ask if the user wants to see only Microsoft publishers or all publishers
    if (-not $searchPublisher) {
        Write-Host "Choose a publisher option:" -ForegroundColor Cyan
        Write-Host "1. Microsoft publishers only (faster)" -ForegroundColor Yellow
        Write-Host "2. Common publishers from various vendors" -ForegroundColor Yellow
        Write-Host "3. All publishers (may take longer to load)" -ForegroundColor Yellow
        Write-Host "4. Search for specific publisher" -ForegroundColor Yellow
        $publisherOption = Read-Host "Select an option (1-4)"
        
        switch ($publisherOption) {
            "1" { 
                Write-Host "Showing only Microsoft publishers..." -ForegroundColor Yellow
                $publishers = Get-MicrosoftPublishers 
                Write-Host "Found $($publishers.Count) Microsoft publishers." -ForegroundColor Green
            }
            "2" { 
                Write-Host "Showing commonly used publishers..." -ForegroundColor Yellow
                $publishers = Get-CommonPublishers 
                Write-Host "Found $($publishers.Count) common publishers." -ForegroundColor Green
            }
            "3" {
                $publishers = Get-AzureVMPublishers -location $location
                if (-not $publishers) {
                    Write-Host "No publishers found or an error occurred. Exiting." -ForegroundColor Red
                    exit 1
                }
                Write-Host "Found $($publishers.Count) publishers in $location." -ForegroundColor Green
            }
            "4" {
                $searchPublisher = Read-Host "Enter publisher name to search (e.g. 'canonical', 'microsoft', etc.)"
                $publishers = Get-AzureVMPublishers -location $location
                if (-not $publishers) {
                    Write-Host "No publishers found or an error occurred. Exiting." -ForegroundColor Red
                    exit 1
                }
                $publishers = $publishers | Where-Object { $_.name -like "*$searchPublisher*" }
                Write-Host "Found $($publishers.Count) publishers matching '$searchPublisher' in $location." -ForegroundColor Green
            }
            default { 
                $publishers = Get-AzureVMPublishers -location $location
                if (-not $publishers) {
                    Write-Host "No publishers found or an error occurred. Exiting." -ForegroundColor Red
                    exit 1
                }
                Write-Host "Found $($publishers.Count) publishers in $location." -ForegroundColor Green
            }
        }
    }
    else {
        # User provided a search term via parameter
        $publishers = Get-AzureVMPublishers -location $location
        if (-not $publishers) {
            Write-Host "No publishers found or an error occurred. Exiting." -ForegroundColor Red
            exit 1
        }
        $publishers = $publishers | Where-Object { $_.name -like "*$searchPublisher*" }
        Write-Host "Found $($publishers.Count) publishers matching '$searchPublisher' in $location." -ForegroundColor Green
    }
}

# Exit if no publishers found
if ($publishers.Count -eq 0) {
    Write-Host "No publishers found matching your criteria. Exiting." -ForegroundColor Red
    exit 1
}

# Step 2: Select a publisher
$selectedPublisher = Show-PaginatedList -itemList $publishers -title "VM Image Publishers" -pageSize $pageSize
if (-not $selectedPublisher) {
    Write-Host "No publisher selected. Exiting." -ForegroundColor Yellow
    exit 0
}

$publisherName = $selectedPublisher.name
Write-Host "Selected publisher: $publisherName" -ForegroundColor Green

# Step 3: Get offers from the selected publisher
$offers = Get-AzureVMOffers -location $location -publisher $publisherName
if (-not $offers) {
    Write-Host "No offers found for publisher $publisherName or an error occurred. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($offers.Count) offers from publisher $publisherName." -ForegroundColor Green

# Step 4: Select an offer
$selectedOffer = Show-PaginatedList -itemList $offers -title "VM Image Offers for $publisherName" -pageSize $pageSize
if (-not $selectedOffer) {
    Write-Host "No offer selected. Exiting." -ForegroundColor Yellow
    exit 0
}

$offerName = $selectedOffer.offer
Write-Host "Selected offer: $offerName" -ForegroundColor Green

# Step 5: Get SKUs for the selected publisher and offer
$skus = Get-AzureVMSkus -location $location -publisher $publisherName -offer $offerName
if (-not $skus) {
    Write-Host "No SKUs found for publisher $publisherName and offer $offerName or an error occurred. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($skus.Count) SKUs for publisher $publisherName and offer $offerName." -ForegroundColor Green

# Step 6: Select a SKU (optional)
$selectedSku = Show-PaginatedList -itemList $skus -title "VM Image SKUs for ${publisherName}:${offerName}" -pageSize $pageSize
if (-not $selectedSku) {
    Write-Host "No SKU selected. Exiting." -ForegroundColor Yellow
    exit 0
}

$skuName = $selectedSku.sku
Write-Host "Selected SKU: $skuName" -ForegroundColor Green

# Display image versions and detailed information
$versions = Get-AzureVMImageVersions -location $location -publisher $publisherName -offer $offerName -sku $skuName
$imageDetail = $null
$latestVersion = $null

if ($versions -and $versions.Count -gt 0) {
    # Get detailed information for the latest version
    $latestVersion = $versions[-1].version
    Write-Host "`nLatest available version: $latestVersion" -ForegroundColor Green
    # Version details are included in the generated report, no need to display here
} 
else {
    Write-Host "No version information available." -ForegroundColor Yellow
}

# Get image details silently
try {
    if ($latestVersion) {
        $imageDetail = Get-ImageDetail -location $location -publisher $publisherName -offer $offerName -sku $skuName -version $latestVersion
    }
    else {
        $imageDetail = Get-ImageDetail -location $location -publisher $publisherName -offer $offerName -sku $skuName
    }
}
catch {
    Write-Host "`nError retrieving image details: $_" -ForegroundColor Red
    $imageDetail = $null
}

if (-not $imageDetail) {
    Write-Host "`nNo detailed information available for this image." -ForegroundColor Yellow
}

# Save the result to a file
$resultFile = "azure-image-$($publisherName.ToLower())-$($offerName.ToLower())-$($skuName.ToLower())-$(Get-Date -Format 'yyyyMMdd').md"
@"
# Azure VM Image Selection
Here's your image 📀 thanks to 🧙 [Kelomai](https://kelomai.io) 🚀
<br>
Report Date: $(Get-Date)
<br>
Region: $($location.ToUpper())

## Image Reference
| Property | Value |
|----------|-------|
| Publisher | $publisherName |
| Offer | $offerName |
| SKU | $skuName |
| Latest Version | $(if ($latestVersion) { $latestVersion } else { "N/A" }) |
| OS Type | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('osDiskImage').Count -gt 0 -and $imageDetail.osDiskImage.PSObject.Properties.Match('operatingSystem').Count -gt 0) { $imageDetail.osDiskImage.operatingSystem } else { "N/A" }) |
| Hyper-V Generation | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('hyperVGeneration').Count -gt 0) { $imageDetail.hyperVGeneration } else { "N/A" }) |
| Architecture | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('architecture').Count -gt 0) { $imageDetail.architecture } else { "N/A" }) |
| Image State | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('imageDeprecationStatus').Count -gt 0 -and $null -ne $imageDetail.imageDeprecationStatus -and $imageDetail.imageDeprecationStatus.PSObject.Properties.Match('imageState').Count -gt 0) { $imageDetail.imageDeprecationStatus.imageState } else { "N/A" }) |
| Security Type | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('SecurityType').Count -gt 0) { $imageDetail.SecurityType } else { "N/A" }) |
| Accelerated Networking | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('acceleratedNetworking').Count -gt 0) { $imageDetail.acceleratedNetworking } else { "N/A" }) |
| Disk Controller Types | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('diskControllerTypes').Count -gt 0) { $imageDetail.diskControllerTypes } else { "N/A" }) |
| Hibernate Support | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('hibernateSupport').Count -gt 0) { $imageDetail.hibernateSupport } else { "N/A" }) |
| Automatic OS Upgrade Supported | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('automaticOSUpgradeProperties').Count -gt 0 -and $null -ne $imageDetail.automaticOSUpgradeProperties -and $imageDetail.automaticOSUpgradeProperties.PSObject.Properties.Match('automaticOSUpgradeSupported').Count -gt 0) { $imageDetail.automaticOSUpgradeProperties.automaticOSUpgradeSupported } else { "N/A" }) |
| Disallowed VM Disk Type | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('disallowed').Count -gt 0 -and $null -ne $imageDetail.disallowed -and $imageDetail.disallowed.PSObject.Properties.Match('vmDiskType').Count -gt 0) { $imageDetail.disallowed.vmDiskType } else { "N/A" }) |
| Data Disk Images Available | $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('dataDiskImages').Count -gt 0 -and $null -ne $imageDetail.dataDiskImages) { $imageDetail.dataDiskImages.Count } else { "N/A" }) |

## Quick URI Reference
``````
$publisherName`:$offerName`:$skuName`:latest
``````

## Image Versions
| Version | Status |
|---------|--------|
$(if ($versions) {
    # Create a hashtable to track unique versions
    $uniqueVersions = @{}
    
    # Extract unique versions
    foreach ($ver in $versions) {
        if (-not $uniqueVersions.ContainsKey($ver.version)) {
            $uniqueVersions[$ver.version] = $true
        }
    }
    
    # Sort the versions - take most recent 10 versions to avoid huge tables
    $sortedVersions = $uniqueVersions.Keys | Sort-Object -Property {
        # Parse each segment as an integer for proper version comparison
        $_.Split('.') | ForEach-Object { [int]$_ }
    } | Select-Object -Last 10
    
    # Output markdown table rows with newlines
    $sortedVersions | ForEach-Object { "| $_ | Available |`n" }
} else {
    "| N/A | N/A |`n"
})

## Image Metadata

`````` json
$(if ($imageDetail) { $imageDetail | ConvertTo-Json -Depth 5 } else { "N/A" })
``````
## Bicep Example

`````` yaml
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D4als_v6'  // Choose appropriate size
    }
    storageProfile: {
      imageReference: { //Use the image metadata here
        publisher: '$publisherName'
        offer: '$offerName'
        sku: '$skuName'
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
``````

## Azure CLI Example

`````` bash
az vm create \
  --resource-group myResourceGroup \
  --name myVM \
  --image $publisherName`:$offerName`:$skuName`:latest \
  --admin-username azureuser \
  --public-ip-sku Standard \
  --size Standard_D4als_v6
``````

## Azure Best Practices
- Use the latest version of the image
- Use the latest generation of the VM
- Use Premium_LRS or Premium_ZRS storage for production workloads
- Choose a VM size appropriate for your workload
- Consider using Availability Zones for high availability
- Apply proper tagging for resource management
- For windows VMs, use an admin password that meets complexity requirements
- For Linux VMs, use SSH key authentication instead of passwords
"@ | Out-File -FilePath $resultFile

# Show the User the full path for the result file
Clear-Host
$scriptPath = $PSScriptRoot
$fullReportPath = Join-Path -Path $scriptPath -ChildPath $resultFile
Write-Host "`n✅ Image selection complete! 📀"
Write-Host "Report 📄 saved to '$fullReportPath'" -ForegroundColor Green

# Display image details for the User with property checking
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "Here's your image 📀 thanks to 🧙 Kelomai" -ForegroundColor DarkGreen
Write-Host "Azure Region : $($location.ToUpper())" -ForegroundColor Yellow
Write-Host "Publisher    : $publisherName" -ForegroundColor Magenta
Write-Host "Offer        : $offerName" -ForegroundColor Magenta
Write-Host "SKU          : $skuName" -ForegroundColor Magenta
Write-Host "Image URI    : $publisherName`:$offerName`:$skuName`:latest" -ForegroundColor Magenta
Write-Host "Architecture : $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('architecture').Count -gt 0) { $imageDetail.architecture } else { "N/A" })" -ForegroundColor Magenta
Write-Host "VM Gen       : $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('hyperVGeneration').Count -gt 0) { $imageDetail.hyperVGeneration } else { "N/A" })" -ForegroundColor Magenta
Write-Host "Status       : $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('imageDeprecationStatus').Count -gt 0 -and $null -ne $imageDetail.imageDeprecationStatus -and $imageDetail.imageDeprecationStatus.PSObject.Properties.Match('imageState').Count -gt 0) { $imageDetail.imageDeprecationStatus.imageState } else { "N/A" })" -ForegroundColor Magenta
Write-Host "Security     : $(if ($imageDetail -and $imageDetail.PSObject.Properties.Match('SecurityType').Count -gt 0) { $imageDetail.SecurityType } else { "N/A" })" -ForegroundColor Magenta
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

# **Kelomai - Script Footer Start**
Write-Host -ForegroundColor DarkGray "-----------------------------------------"
Write-Host -ForegroundColor DarkGray "  Thank you 🤝 for exploring 🧠 Kelomai 🌐"
Write-Host -ForegroundColor DarkGray "           https://kelomai.io            "
Write-Host -ForegroundColor DarkGray "-----------------------------------------"
# **Kelomai - Script Footer End**