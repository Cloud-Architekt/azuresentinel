
#requires -version 6.2
#requires -module @{ModuleName = 'AzSentinel'; ModuleVersion = '0.6.15'}

function Get-AzSentinelTemplateRuleUpdates {
    <#
      .SYNOPSIS
      Get updated Azure Sentinel Rule templates within specific time range to compare them with your active rules.
      .DESCRIPTION
      This function can be used to compare latest template rules from Microsoft with your existing (active) rules.
      .EXAMPLES
      Get-AzSentinelTemplateRuleUpdates -WorkspaceName "lab-la-XXXXXXXXXXXX" -SubscriptionId "4d3e5b65-8a52-4b2f-b5cd-XXXXXX" -TimeRange "90"
    #>
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspaceName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [object]$Compare = @('severity', 'query', 'queryFrequency', 'queryPeriod', 'triggerOperator', 'triggerThreshold', 'entityMappings', 'displayName', 'description', 'tactics'),

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$TimeRange = "30"
    )

    process {

        $OutputFolder = "./" + (Get-Date -Format "yyyy-MM-dd") + "_UpdatesOfLast" + $TimeRange + "Days"
        $CSVFile = (Get-Date -Format "yyyy-MM-dd") + "_RuleTemplateChangesSince" + $TimeRange + "Days.csv"
            try {
                $Result = New-Item $OutputFolder -ItemType directory
            }
            
            catch [System.IO.IOException] {
                WriteOutput $_.Exception.Message
            }
            
            catch {
                #Other Errors
            }
        
        Write-Host "Collecting Rule Templates and Active Rules..."
        $LastUpdated = (Get-Date).adddays(-$TimeRange)
        $UpdatedTemplates = Get-AzSentinelAlertRuleTemplates -WorkspaceName $WorkSpaceName -SubscriptionId $SubscriptionId | Where-Object {$_.lastUpdatedDateUTC -gt $LastUpdated}
        $AllCreatedAlertRulesFromTemplates = Get-AzSentinelAlertRule -WorkspaceName $WorkSpaceName -SubscriptionId $SubscriptionId | Where-Object {$_.alertRuleTemplateName -ne $null}
        
        $CompareResults = $UpdatedTemplates | foreach-object {
        
            $TemplateId = $_.name
            $TemplateRule = ($UpdatedTemplates | where-object {$_.name -eq $TemplateId})
            $ActiveRule = ($AllCreatedAlertRulesFromTemplates | Where-Object {$_.alertRuleTemplateName -eq $TemplateId})
        
            if ($ActiveRule.AlertRuleTemplateName -eq $TemplateId) {
        
                $ActiveRuleLastUpdate = $ActiveRule.lastModifiedUtc
        
                $TemplateRule = $TemplateRule | Select-Object -Property $Compare 
                $ActiveRule = $ActiveRule | Select-Object -Property $Compare
            
                $Changes = $Compare | ForEach-Object {
                    $DiffValue = $_
                    if ($TemplateRule.$DiffValue -ne $ActiveRule.$DiffValue) {
                        $DiffValue
                    }
                }
            
                if ($Changes.count -gt 0) {
                    $ExportARFile = $_.DisplayName.Replace(" ","-") + "_ActiveRule"
                    $ExportTRFile = $_.DisplayName.Replace(" ","-") + "_TemplateRule"
                    $ActiveRule | ConvertTo-Yaml | Out-File -FilePath $OutputFolder/$ExportARFile.yaml
                    $TemplateRule | ConvertTo-Yaml | Out-file -FilePath $OutputFolder/$ExportTRFile.yaml
                }
            
                [PSCustomObject]@{
                    Name = $_.displayName
                    TemplateId = $_.name 
                    TemplateRuleUpdate = $_.lastUpdatedDateUTC
                    ActiveRuleUpdate = $ActiveRuleLastUpdate
                    TimeBetweenUpdatesInDays = ($_.lastUpdatedDateUTC - $ActiveRuleLastUpdate).Days
                    Differences = $changes -join ","
                }
            }
        }
        $CompareResults | Sort-Object TemplateRuleUpdate | Export-Csv -Path $CSVFile -Delimiter ";" -NoTypeInformation
        $CompareResults | Sort-Object TemplateRuleUpdate | Format-Table
    }
}
