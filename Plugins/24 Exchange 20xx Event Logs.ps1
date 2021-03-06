$Title = "Exchange 20xx Server Event Logs"
$Header = "Exchange 20xx Server Event Logs"
$Comments = "Exchange Server Event Logs"
$Display = "None"
$Author = "Phil Randal"
$PluginVersion = 2.2
$PluginCategory = "Exchange2010"

# Based on code in http://www.powershellneedfulthings.com/?page_id=281

# Start of Settings
# Exchange Server Logs to Report On
$ReportOnLogs="Application|System"
# Events to exclude (regular expression)
$ExcludeEvents="None"
# Show Event Log Settings
$ShowEventLogSettings=$false
# Report on Errors Only in Exchange Server Logs
$ReportLogErrorsOnly=$False
# End of Settings

# Changelog
## 2.0 : Initial implementation
## 2.1 : Add Server name filter
## 2.2 : Exclude events by regular expression

If ($2007Snapin -or $2010Snapin) {
  $now = Get-Date
  $exServers = Get-ExchangeServer -ErrorAction SilentlyContinue |
    Where { $_.IsExchange2007OrLater -eq $True -and $_.Name -match $exServerFilter } |
	Sort Name
  ForEach ($Server in $exServers) {
	$Target = $Server.Name
    Write-CustomOut "...Collating Event Logs for $Target"
	$eventLogs=[System.Diagnostics.EventLog]::GetEventLogs($Target) |
	  Where {($_.LogDisplayName -match $ReportOnLogs)}
	$warningEvents = @()
	$errorEvents = @()
	$LogSettings = @()
	ForEach ($eventLog in $eventLogs) {
		If ($ShowEventLogSettings) {
			$Details = "" | select "Log Name", "Overflow Action", "Maximum Kilobytes"
			$Details."Log Name" = $eventLog.LogDisplayName
			$MaximumKilobytes = ($eventLog.MaximumKilobytes)
			$Details."Maximum Kilobytes" = $MaximumKilobytes
			$Details."Overflow Action" = $eventLog.OverflowAction
			$LogSettings += $Details
		}
		If (!$ReportLogErrorsOnly) {
		  Write-CustomOut "....getting event log warnings for $($eventLog.LogDisplayName) Log"
		  $warningEvents += ($eventLog.entries) |
 		    ForEach-Object {
			  Add-Member -inputobject $_ -Name LogName -MemberType NoteProperty -Value $eventLog.LogDisplayName -Force -PassThru |
			    where {($_.TimeWritten -ge $now.AddDays(-1))} |
			    where {($_.EntryType -eq "Warning")} |
			    where {($_.Source -like "*MSExchange*" -or $_.Source -like "*ESE*")} |
				where {($_.EventID -notmatch $ExcludeEvents)}
			}
		}
		Write-CustomOut "....getting event log errors for $($eventLog.LogDisplayName) Log"
		$errorEvents += ($eventLog.entries) |
		  ForEach-Object {
		    Add-Member -inputobject $_ -Name LogName -MemberType NoteProperty -Value $eventLog.LogDisplayName -Force -PassThru |
		      where {($_.TimeWritten -ge $now.AddDays(-1))} |
			  where {($_.EntryType -eq "Error")} |
			  where {($_.Source -like "*MSExchange*" -or $_.Source -like "*ESE*")} |
			  where {($_.EventID -notmatch $ExcludeEvents)}
		  }
	}
	$eventLogs = $null
    If ($LogSettings -ne $null) {
 	  $Header = "Server Event Log Settings on $Target"
	  $Comments = "Event Log Settings"
	  $script:MyReport += Get-CustomHeader $Header $Comments
      $script:MyReport += Get-HTMLTable ($LogSettings)
      $script:MyReport += Get-CustomHeaderClose
	  $LogSettings=$null
	}
    If ($WarningEvents -ne $null) {
 	  $Header = "Warning Events on $Target excluding eventIDs '$ExcludeEvents'"
	  $Comments = "Warning Events"
	  $script:MyReport += Get-CustomHeader $Header $Comments
      $script:MyReport += Get-HTMLTable ($WarningEvents | Select EventID, Source, TimeWritten, LogName, Message)
      $script:MyReport += Get-CustomHeaderClose
	  $WarningEvents=$null
	}
    If ($ErrorEvents -ne $null) {
 	  $Header = "Error Events on $Target excluding eventIDs '$ExcludeEvents'"
	  $Comments = "Error Events"
	  $script:MyReport += Get-CustomHeader $Header $Comments
      $script:MyReport += Get-HTMLTable ($ErrorEvents | Select EventID, Source, TimeWritten, LogName, Message)
      $script:MyReport += Get-CustomHeaderClose
	  $ErrorEvents=$null
	}
  }
}
$Comments = "Exchange Server Event Logs"
