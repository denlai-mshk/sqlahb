param (
    [string]$Mode = "read"  # Default to "read" if no parameter is provided
)

# Ensure the required modules are imported
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Install-Module -Name Az.Accounts -AllowClobber -Force
}
Import-Module Az.Accounts

if (-not (Get-Module -ListAvailable -Name Az.Sql)) {
    Install-Module -Name Az.Sql -AllowClobber -Force
}
Import-Module Az.Sql

if (-not (Get-Module -ListAvailable -Name Az.Compute)) {
    Install-Module -Name Az.Compute -AllowClobber -Force
}
Import-Module Az.Compute

<#
# Ensure proper login
$TenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"
try {
    Connect-AzAccount -TenantId $TenantId -ErrorAction Stop
} catch {
    Write-Output "Failed to authenticate. Please ensure you are logged in with the correct account."
    exit
}
#>
# Import the list of subscriptions from sublist.txt
$subscriptions = Import-Csv -Path "sublist.txt" -Delimiter ',' -Header "SubscriptionName", "SubscriptionId" | Select-Object -Skip 1

# Initialize the output files
$outputFile = "findallsqlsvr.txt"
$ahbonlyFile = "findahbonly.txt"
$disabledFile = "resultpaygo.txt"
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}
New-Item -Path $outputFile -ItemType File

if (Test-Path $ahbonlyFile) {
    Remove-Item $ahbonlyFile
}
New-Item -Path $ahbonlyFile -ItemType File

if (Test-Path $disabledFile) {
    Remove-Item $disabledFile
}
New-Item -Path $disabledFile -ItemType File

# Function to log discovery details
function Log-Discovery {
    param (
        [string]$SqlType,
        [string]$LicenseType,
        [string]$vCores,
        [string]$StorageinGB,
        [string]$SubscriptionName,
        [string]$Region,
        [string]$ResourceGroup,
        [string]$SqlName,
        [string]$ResourceId
    )
        $logEntry = "$SqlType, $LicenseType, $vCores, $StorageinGB, $SubscriptionName, $Region, $ResourceGroup, $SqlName, $ResourceId"
    Add-Content -Path $outputFile -Value $logEntry
}

function Log-AHBOnly {
    param (
        [string]$SqlType,
        [string]$LicenseType,
        [string]$vCores,
        [string]$StorageinGB,
        [string]$SubscriptionName,
        [string]$Region,
        [string]$ResourceGroup,
        [string]$SqlName,
        [string]$ResourceId
    )
        $logEntry = "$SqlType, $LicenseType, $vCores, $StorageinGB, $SubscriptionName, $Region, $ResourceGroup, $SqlName, $ResourceId"
    Add-Content -Path $ahbonlyFile -Value $logEntry
}

# Function to log disabled AHB details
function Log-Disabled {
    param (
        [string]$SqlType,
        [string]$LicenseType,
        [string]$vCores,
        [string]$StorageinGB,
        [string]$SubscriptionName,
        [string]$Region,
        [string]$ResourceGroup,
        [string]$SqlName,
        [string]$ResourceId
    )
    $logEntry = "$SqlType, $LicenseType, $vCores, $StorageinGB, $SubscriptionName, $Region, $ResourceGroup, $SqlName, $ResourceId"
    Add-Content -Path $disabledFile -Value $logEntry
}
Log-Discovery -SqlType "SqlType" -LicenseType "LicenseType" -vCores "vCores" -StorageinGB "StorageinGB"  -SubscriptionName "SubscriptionName" -Region "Region" -ResourceGroup "ResourceGroup"  -SqlName "SqlName" -ResourceId "ResourceId"
Log-AHBOnly -SqlType "SqlType" -LicenseType "LicenseType" -vCores "vCores" -StorageinGB "StorageinGB"  -SubscriptionName "SubscriptionName" -Region "Region" -ResourceGroup "ResourceGroup"  -SqlName "SqlName" -ResourceId "ResourceId"
Log-Disabled -SqlType "SqlType" -LicenseType "LicenseType" -vCores "vCores" -StorageinGB "StorageinGB"  -SubscriptionName "SubscriptionName" -Region "Region" -ResourceGroup "ResourceGroup"  -SqlName "SqlName" -ResourceId "ResourceId"

Write-Output "$(Get-Date -Format HH:mm:ss) Job started"
# Loop through each subscription
foreach ($subscription in $subscriptions) {
    Write-Output "$(Get-Date -Format HH:mm:ss) Processing subscriptions: $($subscription.SubscriptionName)"
    $SubscriptionId = $subscription.SubscriptionId
    $SubscriptionName = $subscription.SubscriptionName

    # Check if SubscriptionId or SubscriptionName is empty
    if ([string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($SubscriptionName)) {
        Write-Output "Error: Missing SubscriptionId or SubscriptionName"
        break
    }

    try {
        # Debug output to check the subscription details
        Write-Output "Setting context for Subscription: $SubscriptionName ($SubscriptionId)"

        # Set the current subscription context
        Select-AzSubscription -SubscriptionName $SubscriptionName -ErrorAction Stop

        # Discover SQL Instance Pools
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlInstancePool"
        $sqlInstancePools = Get-AzSqlInstancePool
        foreach ($pool in $sqlInstancePools) {
            if ([string]::IsNullOrEmpty($pool.LicenseType)) {
                continue
            }            
            $vCores = $pool.VCores
            $storageInGB = "0" # no storage attributes in instance pools object
            Log-Discovery -SqlType "sqlmipool" -LicenseType $pool.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.InstancePoolName -ResourceId $pool.Id

            if ($pool.LicenseType -eq "BasePrice") {
                Log-AHBOnly -SqlType "sqlmipool" -LicenseType $pool.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.InstancePoolName -ResourceId $pool.Id
            }
            
            if ($Mode -eq "write" -and $pool.LicenseType -eq "BasePrice") {
                # Disable Azure Hybrid Benefit
                Write-Output "$(Get-Date -Format HH:mm:ss) Processing Set-AzSqlInstancePool"
                Set-AzSqlInstancePool -ResourceGroupName $pool.ResourceGroupName -Name $pool.InstancePoolName -LicenseType "LicenseIncluded"
                
                # Log the successful disablement
                Log-Disabled -SqlType "sqlmipool" -LicenseType $pool.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.InstancePoolName -ResourceId $pool.Id
            }
        }       
        # Discover SQL Managed Instances
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlInstance"
        $sqlManagedInstances = Get-AzSqlInstance
        foreach ($mi in $sqlManagedInstances) {
            if ([string]::IsNullOrEmpty($mi.LicenseType)) {
                continue
            } 
            # Check if the managed instance is affiliated with any pool instance using $mi attributes
            if ($mi.InstancePoolName) {
                continue
            }
                     
            $vCores = $mi.VCores
            $storageInGB = $mi.StorageSizeInGB
            Log-Discovery -SqlType "sqlmi" -LicenseType $mi.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $mi.Location -ResourceGroup $mi.ResourceGroupName -SqlName $mi.ManagedInstanceName -ResourceId $mi.Id

            if ($mi.LicenseType -eq "BasePrice") {
                Log-AHBOnly -SqlType "sqlmi" -LicenseType $mi.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $mi.Location -ResourceGroup $mi.ResourceGroupName -SqlName $mi.ManagedInstanceName -ResourceId $mi.Id
            }
            
            if ($Mode -eq "write" -and $mi.LicenseType -eq "BasePrice") {
                # Disable Azure Hybrid Benefit
                Write-Output "$(Get-Date -Format HH:mm:ss) Processing Set-AzSqlInstance"
                Set-AzSqlInstance -ResourceGroupName $mi.ResourceGroupName -Name $mi.ManagedInstanceName -LicenseType "LicenseIncluded" -Force
                
                # Log the successful disablement
                Log-Disabled -SqlType "sqlmi" -LicenseType $mi.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $mi.Location -ResourceGroup $mi.ResourceGroupName -SqlName $mi.ManagedInstanceName -ResourceId $mi.Id
            }

        }      

        # Discover SQL Servers
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlServer"
        $sqlServers = Get-AzSqlServer
        foreach ($server in $sqlServers) {
            # Discover SQL Databases for each server
            $sqlDatabases = Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName
            foreach ($db in $sqlDatabases) {
                # Exclude databases affiliated with SQL elastic pools
                if (-not $db.ElasticPoolName) {
                    if ([string]::IsNullOrEmpty($db.LicenseType)) {
                        continue
                    }
                    $vCores = $db.Capacity
                    $storageInGB = [math]::Round($db.MaxSizeBytes / 1GB, 2)
                    Log-Discovery -SqlType "sqldb" -LicenseType $db.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $db.Location -ResourceGroup $db.ResourceGroupName  -SqlName $db.DatabaseName -ResourceId $db.ResourceId

                    if ($db.LicenseType -eq "BasePrice") {
                        Log-AHBOnly -SqlType "sqldb" -LicenseType $db.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $db.Location -ResourceGroup $db.ResourceGroupName  -SqlName $db.DatabaseName -ResourceId $db.ResourceId
                    }
                            
                    if ($Mode -eq "write" -and $db.LicenseType -eq "BasePrice") {
                        # Disable Azure Hybrid Benefit
                        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Set-AzSqlDatabase"
                        Set-AzSqlDatabase -ResourceGroupName $db.ResourceGroupName -ServerName $db.ServerName -DatabaseName $db.DatabaseName -LicenseType "LicenseIncluded"
                        
                        # Log the successful disablement
                        Log-Disabled -SqlType "sqldb" -LicenseType $db.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $db.Location -ResourceGroup $db.ResourceGroupName  -SqlName $db.DatabaseName -ResourceId $db.ResourceId
                    }
                }
            }
            # Discover SQL Elastic Pools
            Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlElasticPool"
            $sqlElasticPools = Get-AzSqlElasticPool -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName
            foreach ($pool in $sqlElasticPools) {
                $vCores = $pool.Capacity
                $storageInGB = [math]::Round($pool.StorageMB / 1024, 2)
                Log-Discovery -SqlType "sqlpool" -LicenseType $pool.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.ElasticPoolName -ResourceId $pool.ResourceId

                if ($pool.LicenseType -eq "BasePrice") {
                    Log-AHBOnly -SqlType "sqlpool" -LicenseType $pool.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.ElasticPoolName -ResourceId $pool.ResourceId
                }
                                  
                if ($Mode -eq "write" -and $pool.LicenseType -eq "BasePrice") {
                    # Disable Azure Hybrid Benefit
                    Write-Output "$(Get-Date -Format HH:mm:ss) Processing Set-AzSqlElasticPool"
                    Set-AzSqlElasticPool -ResourceGroupName $pool.ResourceGroupName -ServerName $pool.ServerName -ElasticPoolName $pool.ElasticPoolName -LicenseType "LicenseIncluded"
                    
                    # Log the successful disablement
                    Log-Disabled -SqlType "sqlpool" -LicenseType $pool.LicenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.ElasticPoolName -ResourceId $pool.ResourceId
                }
            }

                   
            
        }


        # Discover SQL Virtual Machines
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing SQL Virtual Machines"
        $sqlVms = Get-AzResource -ResourceType "Microsoft.SqlVirtualMachine/sqlVirtualMachines" -ExpandProperties
        foreach ($sqlVm in $sqlVms) {
            $sqlVmProperties = $sqlVm.Properties
            $licenseType = $sqlVmProperties.sqlServerLicenseType
            $sqlImageSku = $sqlVmProperties.sqlImageSku

            if ($sqlImageSku -ne "Developer") {
                $vCores = "N/A" # vCores might not be directly available
                $storageInGB = "N/A" # Storage details can be complex to extract
                Log-Discovery -SqlType "sqlvm" -LicenseType $licenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $sqlVm.Location -ResourceGroup $sqlVm.ResourceGroupName -SqlName $sqlVm.Name -ResourceId $sqlVm.Id

                if ($LicenseType -eq "AHUB") {
                    Log-AHBOnly -SqlType "sqlvm" -LicenseType $licenseType -vCores $vCores -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $sqlVm.Location -ResourceGroup $sqlVm.ResourceGroupName -SqlName $sqlVm.Name -ResourceId $sqlVm.Id
                }
            }
        }


    } catch {
        Write-Output "Failed to set context for subscription $SubscriptionId. Error: $_"
    }
}

Write-Output "$(Get-Date -Format HH:mm:ss) Discovery and disablement completed. Check the findallsqlsvr.txt, findahbonly.txt and resultpaygo.txt files for details."