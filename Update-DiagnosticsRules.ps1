<#
.SYNOPSIS
Updates diagnostic rules for all resources types mentioned in input json.

Install-Module ImportExcel -AllowClobber -Force  -> to export data in .excls file

Get existing diagnostic configuration. 
Remove existing diagnostic rule configuration (5 seconds sleep period is added to update settings)
Add new diagnostic rule with same configuration but with updated name.

.DESCRIPTION

.PARAMETER $customerTenantId
    Specified the customer's tenant id

.PARAMETER $inputfilePath
    Specifies the input json file path '.\Tag-Conversion-Input.json'

.OUTPUTS
    Log file at same location 'PrerequisitesLogFile-$($tenantID).txt'

.NOTES
    Version:        0.1
    Author:         abhijit.kakade@eviden.com
    Creation Date:  2023/9/15

.EXAMPLE
$params = @{
	tenantID = 'bc57f51a-6d93-46ac-ae9c-c2a2840d090e'
    inputfilePath = '.\Tag-Conversion-Input.json'
}

Update-DiagnosticsRules.ps1 @params
#>


param (
    [Parameter(Mandatory = $True)]
    [string]$tenantID,

    [Parameter(Mandatory = $False)]
    [string]$inputfilePath
)
function WriteOutput {
    param (

        [Parameter(Mandatory = $True)]
        $outputText,

        [Parameter(Mandatory = $False)]
        [bool]
        $isObject = $False
    )
    $timestamp = Get-Date -Format "MM.dd.yyyy HH:mm"
    if ($isObject -eq $True) {
        Write-Output $outputText
        Add-Content -Path ".\Update-DiagnosticsRulesLogFile-$($tenantID).txt" -Value $outputText
    }
    else {
        Write-Output "$timestamp | $outputText"
        Add-Content -Path ".\Update-DiagnosticsRulesLogFile-$($tenantID).txt" -Value "$timestamp | $outputText"
    }
}

# Update diagnostic rule for all internal resoruces of Storage account (BlobService,TableService,QueueService,FileService)
function Update-DiagnosticsRulesForStorageAccountInternalResources {

    param (
        [Parameter(Mandatory = $True)]
        [string]$storageAccountName,

        [Parameter(Mandatory = $True)]
        [string]$storageAccountResourceID
    )

    WriteOutput "Updating diagnostic settings for Storage acocunt (Blob, Queue, Table, File) Services"
    $storageacservices = @('/blobServices/default', '/queueServices/default', '/tableServices/default', '/fileServices/default')

    foreach ($service in $storageacservices) {
        $internalServiceResourcesID = $storageAccountResourceID + $service
        $internalServiceDiagnosticSettings = Get-AzDiagnosticSetting -ResourceId $internalServiceResourcesID

        if ($null -ne $internalServiceDiagnosticSettings) {
            if ($internalServiceDiagnosticSettings.Name.Contains('Atos') -or $internalServiceDiagnosticSettings.Name.Contains('atos')) {

                WriteOutput "Removing existing Diagnostics rule for Resource - $service -> $internalServiceResourcesID"
                Remove-AzDiagnosticSetting -Name $internalServiceDiagnosticSettings.Name -ResourceId $internalServiceResourcesID
                WriteOutput "Sucessfully Removed existing Diagnostics rule for Resource - $service "
                WriteOutput "Wait for 5 seconds.. "
                Start-Sleep -Seconds 5

                $resourceDiagnosticSettings_Name = $internalServiceDiagnosticSettings.Name.Replace('Atos', 'Eviden')
                $resourceDiagnosticSettings_Metric = $internalServiceDiagnosticSettings.Metric
                $resourceDiagnosticSettings_workspaceID = $internalServiceDiagnosticSettings.WorkspaceId
                $resourceDiagnosticSettings_LogAnalyticsDestinationType = $internalServiceDiagnosticSettings.LogAnalyticsDestinationType

                New-AzDiagnosticSetting -Name $resourceDiagnosticSettings_Name -ResourceId $internalServiceResourcesID -WorkspaceId $resourceDiagnosticSettings_workspaceID -Metric $resourceDiagnosticSettings_metric -LogAnalyticsDestinationType $resourceDiagnosticSettings_LogAnalyticsDestinationType
                WriteOutput "Sucessfully enabled diagnostics settings for resource - $service"
            }
        }
    }

}

## Login into Azure tenant
$global:tenantID = $tenantID

#region AZ Login
try {

    $azConnect = Connect-AzAccount -tenantID $tenantID

    if (-not $azConnect) {

        WriteOutput "Login error: Logging into azure Failed..."
        Write-Error "Login error: Logging into azure Failed..." -ErrorAction 'Stop'

    }
    else {
        WriteOutput "Successfully logged into the Azure Platform."
    }
}
catch {
    throw $_.Exception
}
#endregion AZ Login

# Install PS Module
Install-Module ImportExcel -AllowClobber -Force

# Load JSON file
$inputJsonTagList = Get-Content -Path $inputfilePath -Raw | ConvertFrom-Json

WriteOutput "-------------------Input JSON File ----------------------------"
WriteOutput (ConvertTo-Json $inputJsonTagList ) -isobject $true
$Subscriptions = $inputJsonTagList.Subscriptions
#$Subscriptions = Get-AzSubscription -tenantID $tenantID
WriteOutput $Subscriptions -isObject $true

# List or resource with status
WriteOutput "Updating Diagnostic rules for all resources."

try {

    $Outputlist = New-Object Collections.Generic.List[PSObject]
    #Looping through each and every subscription to update diagnostic rule
    foreach ($sub in $Subscriptions) {

        #Setting context so the script will be executed within the subscription's scope
        Get-AzSubscription -SubscriptionName $sub.SubscriptionName -TenantId $tenantID | Set-AzContext
        WriteOutput "Subscription $($sub.SubscriptionName) selected."

        WriteOutput "Check Diagnostic settings on Subscription $($sub.SubscriptionName)"
        $subDiagnosticSettings = get-AzDiagnosticSetting -ResourceId "/subscriptions/$($sub.SubscriptionID)"

        if ($null -ne $subDiagnosticSettings ) {

            if ($subDiagnosticSettings.Name.Contains('Atos') -or $subDiagnosticSettings.Name.Contains('atos')) {
                WriteOutput "Removing existing Diagnostics rule for Subscription - $($sub.SubscriptionName)"
                Remove-AzDiagnosticSetting -Name $subDiagnosticSettings.Name -ResourceId "/subscriptions/$($sub.SubscriptionID)"
                WriteOutput "Sucessfully Removed existing Diagnostics rule for Subscription - $($sub.SubscriptionName)"
                WriteOutput "Wait for 5 seconds.. "
                Start-Sleep -Seconds 5

                WriteOutput "Adding new diagnostics rule for Subscription - $($sub.SubscriptionName)"
                $SubDiagnosticSettings_Name = $subDiagnosticSettings.Name.Replace('Atos', 'Eviden')
                $SubDiagnosticSettings_Metric = $subDiagnosticSettings.Metric
                $SubDiagnosticSettings_log = $subDiagnosticSettings.Log
                $SubDiagnosticSettings_workspaceID = $subDiagnosticSettings.WorkspaceId
                $subDiagnosticSettings_LogAnalyticsDestinationType = $subDiagnosticSettings.LogAnalyticsDestinationType

                New-AzDiagnosticSetting -Name $SubDiagnosticSettings_Name -ResourceId "/subscriptions/$($sub.SubscriptionID)" -WorkspaceId $SubDiagnosticSettings_workspaceID -Log $SubDiagnosticSettings_log -Metric $SubDiagnosticSettings_metric -LogAnalyticsDestinationType $subDiagnosticSettings_LogAnalyticsDestinationType
                WriteOutput "Sucessfully enabled diagnostics settings for Subscription - $($sub.SubscriptionName)"

            }
        }

        foreach ($resourceType In $inputJsonTagList.DiagnosticsConfigResourceType) {
            $resourceList = Get-AzResource -ResourceType $resourceType
            foreach ($resource in $resourceList) {

                $ResourceObject = New-Object PSObject -Property @{
                    ResourceID                          = $resource.Id
                    ResourceName                        = $resource.Name
                    hasExistingDiagnosticRuleConfigured = $False
                    hasAtosDignosticsRuleConfigured     = $False
                    ExistingDiagnosticsRuleName         = ""
                    RemovedExistingDiagnosticsRule      = $False
                    AddedNewDiagnosticsRule             = $False
                    StatusMessage                       = ""
                }
                $resourceDiagnosticSettings = Get-AzDiagnosticSetting -ResourceId $resource.Id
                if ($null -ne $resourceDiagnosticSettings) {

                    $ResourceObject.hasExistingDiagnosticRuleConfigured = $True
                    $ResourceObject.ExistingDiagnosticsRuleName = $resourceDiagnosticSettings.Name
                    if ($resourceDiagnosticSettings.Name.Contains('Atos') -or $resourceDiagnosticSettings.Name.Contains('atos')) {
                        $ResourceObject.hasAtosDignosticsRuleConfigured = $True

                        WriteOutput "Removing existing Diagnostics rule for Resource - $($resource.Name) -('$($resource.Type)'"
                        Remove-AzDiagnosticSetting -Name $resourceDiagnosticSettings.Name -ResourceId $resource.Id
                        WriteOutput "Sucessfully Removed existing Diagnostics rule for Resource - $($resource.Name) -('$($resource.Type)'"
                        WriteOutput "Wait for 5 seconds.. "
                        Start-Sleep -Seconds 5
                        $ResourceObject.RemovedExistingDiagnosticsRule = $True
                        $resourceDiagnosticSettings_Name = $resourceDiagnosticSettings.Name.Replace('Atos', 'Eviden')
                        $resourceDiagnosticSettings_Metric = $resourceDiagnosticSettings.Metric
                        $resourceDiagnosticSettings_log = $resourceDiagnosticSettings.Log
                        $resourceDiagnosticSettings_workspaceID = $resourceDiagnosticSettings.WorkspaceId
                        $resourceDiagnosticSettings_LogAnalyticsDestinationType = $resourceDiagnosticSettings.LogAnalyticsDestinationType

                        WriteOutput "New Diagnostic Rule Object"
                        WriteOutput "resourceDiagnosticSettings_Name - $resourceDiagnosticSettings_Name"
                        WriteOutput "resourceDiagnosticSettings_Metric - $resourceDiagnosticSettings_Metric"
                        WriteOutput "resourceDiagnosticSettings_log - $resourceDiagnosticSettings_log"
                        WriteOutput "resourceDiagnosticSettings_workspaceID - $resourceDiagnosticSettings_workspaceID"
                        WriteOutput "resourceDiagnosticSettings_LogAnalyticsDestinationType - $resourceDiagnosticSettings_LogAnalyticsDestinationType"
                        try {

                            New-AzDiagnosticSetting -Name $resourceDiagnosticSettings_Name -ResourceId  $resource.Id -WorkspaceId $resourceDiagnosticSettings_workspaceID -Log $resourceDiagnosticSettings_log -Metric $resourceDiagnosticSettings_metric -LogAnalyticsDestinationType $resourceDiagnosticSettings_LogAnalyticsDestinationType

                        }
                        catch {
                            $ResourceObject.AddedNewDiagnosticsRule = $False
                            $ResourceObject.StatusMessage = "Error while adding new Diagnostic Rule $_"
                        }
                        $ResourceObject.AddedNewDiagnosticsRule = $True
                        WriteOutput "Sucessfully enabled diagnostics settings for Resource - $($resource.Name) - with name."
                        $ResourceObject.StatusMessage = "Sucessfully enabled diagnostics settings."
                    }
                    else {
                        $ResourceObject.hasAtosDignosticsRuleConfigured = $False
                        WriteOutput "Eviden Diagnostic settings already configured on Resource - $($resource.Name) -('$($resource.Type)' - Existing Rule Name $($resourceDiagnosticSettings.Name))."
                        $ResourceObject.StatusMessage = "Eviden Diagnostic settings already configured on Resource."
                    }
                }
                else {

                    $ResourceObject.hasExistingDiagnosticRuleConfigured = $False
                    WriteOutput "Diagnostic settings not configured on Resource - $($resource.Name) -('$($resource.Type)')."
                    $ResourceObject.StatusMessage = "Diagnostic settings not configured on Resource."
                }

                if ($resourceType -eq 'Microsoft.Storage/storageAccounts') {
                    WriteOutput "Updating diagnostic settings of Storage acocunt internal services."
                    Update-DiagnosticsRulesForStorageAccountInternalResources -storageAccountName $resource.Name -storageAccountResourceID $resource.Id
                }
                $Outputlist.Add($ResourceObject)
            }
        }
    }

    $timestamp = Get-Date -Format "MMddyyyyHHmmss"
    $Outputlist | Select-Object ResourceID, ResourceName, hasExistingDiagnosticRuleConfigured, ExistingDiagnosticsRuleName, hasAtosDignosticsRuleConfigured, RemovedExistingDiagnosticsRule, AddedNewDiagnosticsRule, StatusMessage | Export-Excel -Path ".\diagnosticsRuleUpdationStatus$($timestamp) .xlsx"
    WriteOutput "Diagnostics rules updation completed."
}
catch {
    WriteOutput "Error : Diagnostics rules updation failed.. "
    WriteOutput $_ -isObject $True
}
