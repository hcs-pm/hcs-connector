#Credit to https://github.com/kprocyszyn

#This loops through all of the VSS writers in a state you specify: 'Stable', 'Failed', 'Waiting for completion'. Then it attempts to restart their associated service, sometimes killing the service process if needed. There are 3 components to it all Get-VSSWriter - gets writers in a specified state; Restart-Writer - restarts specified writers, you can feed one command into the other, eg: get-vsswriter failed | restart-vsswriter ← restarts all VSS writers in a failed state;

#For dot sourcing
Write-host "Successfully imported Get-VSSWriter, Restart-VSSWriter, Restart-VSSWriters (WIP)"
function Get-VSSWriter {
	[CmdletBinding()]
	
	Param (
		[ValidateSet('Stable', 'Failed', 'Waiting for completion')]
		[String]
		$Status
	) #Param

	Process {
		#Command to retrieve all writers, and split them into groups
		Write-Verbose "Retrieving VSS Writers"
		VSSAdmin list writers |
		Select-String -Pattern 'Writer name:' -Context 0, 4 |
		ForEach-Object {

			#Removing clutter
			Write-Verbose "Removing clutter "
			$Name = $_.Line -replace "^(.*?): " -replace "'"
			$Id = $_.Context.PostContext[0] -replace "^(.*?): "
			$InstanceId = $_.Context.PostContext[1] -replace "^(.*?): "
			$State = $_.Context.PostContext[2] -replace "^(.*?): "
			$LastError = $_.Context.PostContext[3] -replace "^(.*?): "

			#Create object
			Write-Verbose "Creating object"
			foreach ($Prop in $_) {
				$Obj = [pscustomobject]@{
					Name       = $Name
					Id         = $Id
					InstanceId = $InstanceId
					State      = $State
					LastError  = $LastError
				}
			}#foreach

			#Change output based on Status provided
			If ($PSBoundParameters.ContainsKey('Status')) {
				Write-Verbose "Filtering out the results"
				$Obj | Where-Object { $_.State -like "*$Status" }
			} #if
			else {
				$Obj
			} #else

		}#foreach-object
	}

}#function

function Restart-VSSWriter {
	[CmdletBinding()]

	Param (
		[Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $True)]
		[String[]]
		$Name
	) #Param
	
	Process {
		
		Write-Verbose "Working on VSS Writer: $Name"
		Switch ($Name) {
			'ASR Writer' { $Service = 'VSS' }
			'BITS Writer' { $Service = 'BITS' }
			'Certificate Authority' { $Service = 'EventSystem' }
			'COM+ REGDB Writer' { $Service = 'VSS' }
			'DFS Replication service writer' { $Service = 'DFSR' }
			'DHCP Jet Writer' { $Service = 'DHCPServer' }
			'FRS Writer' { $Service = 'NtFrs' }
			'FSRM writer' { $Service = 'srmsvc' }
			'IIS Config Writer' { $Service = 'AppHostSvc' }
			'IIS Metabase Writer' { $Service = 'IISADMIN' }
			'Microsoft Exchange Replica Writer' { $Service = 'MSExchangeRepl' }
			'Microsoft Exchange Writer' { $Service = 'MSExchangeIS' }
			'Microsoft Hyper-V VSS Writer' { $Service = 'vmms' }
			'MSMQ Writer (MSMQ)' { $Service = 'MSMQ' }
			'MSSearch Service Writer' { $Service = 'WSearch' }
			'NPS VSS Writer' { $Service = 'EventSystem' }
			# 'NTDS' { $Service = 'NTDS' }
			'OSearch VSS Writer' { $Service = 'OSearch' }
			'OSearch14 VSS Writer' { $Service = 'OSearch14' }
			'Registry Writer' { $Service = 'VSS' }
			'Shadow Copy Optimization Writer' { $Service = 'VSS' }
			'SMS Writer' { $Service = 'SMS_SITE_VSS_WRITER' }
			'SPSearch VSS Writer' { $Service = 'SPSearch' }
			'SPSearch4 VSS Writer' { $Service = 'SPSearch4' }
			'SqlServerWriter' { $Service = 'SQLWriter' }
			'System Writer' { $Service = 'CryptSvc' }
			'TermServLicensing' { $Service = 'TermServLicensing' }
			'WDS VSS Writer' { $Service = 'WDSServer' }
			'WIDWriter' { $Service = 'WIDWriter' }
			'WINS Jet Writer' { $Service = 'WINS' }
			'WMI Writer' { $Service = 'Winmgmt' }
			default { $Service = $Null }
		} #Switch

		IF ($Service) {
			Write-Verbose "Found matching service"
			$S = Get-Service -Name $Service
			Write-Host "Restarting service $(($S).DisplayName)"
			$S | Restart-Service -Force

			#Obtaining service process ID using queryex
			if(!$?){
				# $service_pid = (get-wmiobject win32_service | where { $_.name -eq $S.Name}).processID ← this doesn't get the right PID
				$service_pid = sc.exe queryex $S.Name | select-string -pattern "PID" | ForEach-Object { $_ -replace '.+: (\d+)', '$1'}
				Write-Host "Obtained PID: $service_pid"
				write-host "attempting to restart $(($S).DisplayName)... killing process $($service_pid)"
				# Stop-Process -Id $service_pid -force ← appears this can fail
				taskkill /f /t /pid $service_pid
				$S | Restart-Service -Force -Verbose
			}
		}
		ELSE {
			Write-Warning "No service associated with VSS Writer: $Name"
		}
	}


}

# use like this ↓↓
# Get-VSSWriter Failed | Restart-VSSWriter
# ↑↑



#Restart-Writers accepts a writer state as an argument, loops through every writer with speciefied state, restarts its associated services, sometimes killing the process if needed. It does so indefinitely, for as long as there are writers in a given state, or for a limited number of time to limit number of attempts set a $limit variable before function call. ← this will change as I'm not a huge fan of this approach;

#Function still needs the other 2 functions defined in this file to work;

#Example use: Restart-VSSWriters Failed will get all the writers in failed state and restart them all indefinitely or fixed amount of times

# ↓↓↓ this is WIP, needs testing ↓↓↓
#hacky hax, variable outside function scope to keep track of attempts
$limit = 0
function Restart-VSSWriters{
	[CmdletBinding()]
	Param (
		[String]
		$State
	) 

	#get writers
	$Writers = @();
	$Writers += Get-VSSWriter $State;

	#checkstate;
	foreach ($writer in $Writers) {
			Restart-VSSWriter $writer.name
	}
	if ($limit -ne $null){
		$limit++
		write-host "Current attempt: $limit"
	}
	#check writer collection array length, if not empty start recursive call
	if ($writers.count -eq 0){
		write-host "No writers in state $State. Script exit."
		return
	} else {
		if ($limit -ne 3 -or $limit -eq $null){
		Restart-VSSWriters $State;
	}
	}
}

# ↑↑↑ WIP ↑↑↑
