#powershell 5
@"
Server Name: $(hostname)
Type/Model: $($isvm = (get-item "HKLM:\software\Labtech\Service").getvalue("ID");if ($isvm){$vm = "VM"} else {$vm = "Physical machine"};$vm)
Serial#: $((Get-WmiObject win32_bios).serialnumber)
OS Name: $((Get-WmiObject Win32_OperatingSystem).Caption)
Proposed solution:
Screenshots:
"@ | clip
#Powershell 7
@"
Server Name: $(hostname)
Type/Model: $($isvm = (get-item "HKLM:\software\Labtech\Service").getvalue("ID");if ($isvm){$vm = "VM"} else {$vm = "Physical machine"};$vm)
Serial#: $((get-ciminstance -class "win32_bios").serialnumber)
OS Name: $((get-ciminstance -class "Win32_OperatingSystem").Caption)
Proposed solution:
Screenshots:
"@ | clip