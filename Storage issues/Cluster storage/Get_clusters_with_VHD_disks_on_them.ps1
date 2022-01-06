#region TO-DO
    #Write native function that looks for files in the given folder and its subfolders
    #Check if there are existing file(s) by export paths
#endregion TO-DO 
function Get-Clusters-With-VHD-Disks {
    <#
    .SYNOPSIS
        Gets information about cluster storage(s), VHD disk(s) and other files on them and optionally exports it using several export formats.
    .DESCRIPTION
        Gathers the information about the cluster volumes, the VHD disks that are located on those storages and about the other files that also 
        take space on the clusters. The information mainly consists of different statistic about amount of free/used/allocated space on the storage(s) 
        and drive(s) and relations between those units. The found information can be viewed in the PowerShell console or can be exported as CSV files 
        and\or as raw data file that can be recreated in the PowerShell on the other computer.
    .PARAMETER vmHostNames
        Specify name(s) of virtual hosts where you will be looking for hosted VMs and their information.
    .PARAMETER exportFolder
        Provide path to the existing folder where exported file(s) will be stored. If you omit the parameter default path "C:\hocs_temp" will be used. 
    .PARAMETER exportCsv
        Use the parameter if you want to get results as CSV file(s). The file(s) will be exported to the default folder "C:\hocs_temp" 
        or to the folder that you specified in "exportFolder" parameter.
    .PARAMETER exportRawObject
        Use the parameter to get results in form of exported object. Such object can be moved to other computer(s) and recreated there in other PowerShell 
        session by using build-in-to-PowerShell "Import-Clixml" cmdlet.
    .EXAMPLE
        Get-Clusters-With-VHD-Disks -vmHostNames "VMHOST1","VMHOST2","VMHOST3"
        -----------
        Gets cluster and virtual disks on them from the specified vmhosts and displays information in the console. 
    .EXAMPLE
        Get-Clusters-With-VHD-Disks -vmHostNames "VMHOST1" -exportCSV -exportFolder "C:\new_folder"
        -----------
        Gets cluster and virtual disks and exports the information as CSV file(s) to the specified folder.
    .EXAMPLE
        Get-Clusters-With-VHD-Disks -vmHostNames "VMHOST2","VMHOST3" -exportRawObject
        -----------
        Gets cluster and virtual disks and exports the information as serialized object to the default folder "C:\hocs_temp". 
    .NOTES
        FunctionName    : Get-Clusters-With-VHD-Disks 
        Version         : 1.2
        Date Modified   : 19-Nov-21 03:00 PM
    #>


    [CmdletBinding()]
    param (
        [Parameter( 
            Mandatory=$true,
            HelpMessage="Provide name(s) of virtual host(s) where VHDX file(s) of hosted VM(s) should be found.")]
        [string[]]$vmHostNames = @(),

        [Parameter(
            HelpMessage="Provide path to the existing folder to save export files into.")] 
        [ValidateScript({Test-Path $_ -PathType Container})] 
        [string]$exportFolder = "$($env:systemDrive)\hocs_temp",

        [switch]$exportCsv,
        
        [switch]$exportRawObject
    )
    process {
        try {
            Import-Module C:\Windows\system32\WindowsPowerShell\v1.0\Modules\FailoverClusters\FailoverClusters.psd1;
            Write-Verbose "`nGetting VHD disk(s) info...";
            $allFoundVHDDrives = @();
            foreach ($name in $vmHostNames) {
                Write-Verbose "Working with $name"
                get-vm -ComputerName $name | ForEach-Object {
                    Write-Verbose "Working with $_";
                    $allDrivesOfCurrentVM = $_.HardDrives;
                    foreach ($driveOfCurrentVM in $allDrivesOfCurrentVM){
                        if (Test-Path "$($driveOfCurrentVM.Path)") {
                            $drive = [pscustomobject][ordered]@{ 
                                vmName = $_.Name;
                                pathToDrive = $driveOfCurrentVM.Path;
                                isPresentByThePath = $true;
                                currentDriveSizeGB = [System.Math]::Round(((get-vhd -ComputerName $name -Path $driveOfCurrentVM.Path -ErrorAction SilentlyContinue).FileSize) / 1GB, 2);
                                allocatedDriveSizeGB =  [System.Math]::Round(((get-vhd -ComputerName $name -Path $driveOfCurrentVM.Path -ErrorAction SilentlyContinue).Size) / 1GB, 2);
                                currentDriveSizeGBPercentOfCsvVolume = [int]-1
                                allocatedDriveSizeGBPercentOfCsvVolume = [int]-1
                            }
                        }
                        else {
                            $drive = [pscustomobject][ordered]@{ 
                                vmName = $_.Name;
                                pathToDrive = $driveOfCurrentVM.Path;
                                isPresentByThePath = $false;
                            }
                        }
                        $allFoundVHDDrives += $drive;
                    }
                }
            }
            Write-Verbose "Found $($allFoundVHDDrives.Count) VHD disk(s).";
    
            Write-Verbose "`nGetting CSV info...";
            $clusterSharedVolumes = @();
            $allFoundCsv = Get-ClusterSharedVolume;
            foreach ($csv in $allFoundCsv) {
                $clusterSharedVolume = [pscustomobject][ordered]@{
                    name = $csv.Name;
                    path = $csv.SharedVolumeInfo.FriendlyVolumeName;
                    totalSizeGB = [System.Math]::Round(($csv.SharedVolumeInfo.Partition.Size / 1GB), 2);
                    freeSpaceGB = [System.Math]::Round(($csv.SharedVolumeInfo.Partition.FreeSpace / 1GB), 2);
                    usedSpaceGB = [System.Math]::Round(($csv.SharedVolumeInfo.Partition.UsedSpace / 1GB), 2);
                    percentFree = [System.Math]::Round($csv.SharedVolumeInfo.Partition.PercentFree, 2);
                    vhdDrives = @();
                }
                $clusterSharedVolumes += $clusterSharedVolume;
            }
            Write-Verbose "Found $($clusterSharedVolumes.Count) cluster storage(s).";

            Write-Verbose "`nProcessing CSV and VHD disk(s) info...`n";
            foreach ($clusterSharedVolume in $clusterSharedVolumes) {
                foreach ($vhdDrive in $allFoundVHDDrives) {
                    if (($vhdDrive.pathToDrive).Contains($clusterSharedVolume.path)) {
                        if (($vhdDrive.isPresentByThePath)) {
                            $vhdDrive.currentDriveSizeGBPercentOfCsvVolume = [System.Math]::Round((($vhdDrive.currentDriveSizeGB / $clusterSharedVolume.totalSizeGB) * 100) , 2);
                            $vhdDrive.allocatedDriveSizeGBPercentOfCsvVolume = [System.Math]::Round((($vhdDrive.allocatedDriveSizeGB / $clusterSharedVolume.totalSizeGB) * 100), 2);
                        }
                        $clusterSharedVolume.vhdDrives += $vhdDrive;
                    }
                }
            }

            #Function may not return all the found files due to the access errors
            Write-Verbose "Getting info about miscellanious items on cluster storage(s)...";
            foreach ($clusterSharedVolume in $clusterSharedVolumes) {
                $miscellaniousItems = @();
                Add-Member -InputObject $clusterSharedVolume -type NoteProperty -name "misc_items" -value "";
                $clusterSharedVolume.misc_items = @();
                Write-Verbose "`nWorking with $($clusterSharedVolume.path) path";
                try {
                    Get-ChildItem -Path $($clusterSharedVolume.path) -File -Force -Recurse -Exclude "*.vhdx" -ErrorAction SilentlyContinue -OutVariable miscellaniousItems | out-null;
                }
                catch { }
                Write-Verbose "`nFound $($miscellaniousItems.Count) miscellanious items";
                foreach ($path in $miscellaniousItems) {
                    try {
                        $itemProperty = (Get-Item $path -Force -ErrorAction Inquire);
                        $path = "$($itemProperty.FullName)";
                        $sizeMB = "$([System.Math]::Round($($itemProperty.Length / 1mb), 2))";
                        $misk_item = New-Object -TypeName psobject -Property @{
                            path = $path;
                            sizeMB = $sizeMB;
                        }
                        $clusterSharedVolume.misc_items += $misk_item;
                        Write-Verbose "Item by path $path has size of $sizeMB MB";
                    }
                    catch {
                        $_;
                    }
                }
            }
            

            if ($exportCsv) {
                Write-Verbose "`nExporting the results as CSV file(s) to the '$($exportFolder)' folder...";
                $exportFileNames = @("Disk_Information", "VM_Info_Disk", "Misc_files")

                Write-Verbose "`nExporting the $($exportFileNames[0])";
                $disk_Information = $clusterSharedVolumes | Select-Object -Property name, path, totalSizeGB, freeSpaceGB, usedSpaceGB, percentFree;
                $disk_Information | Export-Csv -Path "$($env:SystemDrive)\hocs_temp\Disk_Information.csv" -NoTypeInformation;

                Write-Verbose "`nExporting the $($exportFileNames[1])";
                foreach ($clusterSharedVolume in $clusterSharedVolumes) {
                    Write-Host "`nWorking with $($clusterSharedVolume.Name)";
                    $vm_Info_Disk = $clusterSharedVolume.vhdDrives | Select-Object -Property vmName, pathToDrive, currentDriveSizeGB;
                    $vm_Info_Disk | Export-Csv -Path "$($env:SystemDrive)\hocs_temp\VM_Info-$($clusterSharedVolume.Name).csv" -NoTypeInformation;
                }

                Write-Verbose "`nExporting the $($exportFileNames[2])";
                foreach ($clusterSharedVolume in $clusterSharedVolumes) { 
                    Write-Host "`nWorking with $($clusterSharedVolume.Name)";
                    $misc_files = $clusterSharedVolume.misc_items | Select-Object -Property path, sizeMB;
                    $misc_files | Export-Csv -Path "$($env:SystemDrive)\hocs_temp\Misc_files-$($clusterSharedVolume.Name).csv" -NoTypeInformation;
                }
            }

            if ($exportRawObject) {
                Write-Verbose "`nExporting the results as raw file to the '$($exportFolder)' folder...";
                $clusterSharedVolumes | Export-Clixml -Path $(Join-Path -Path $exportFolder -ChildPath "(Raw)_Cluster_storage_with_vhdx_drives.tmp");
            }

            return $clusterSharedVolumes;
        }
        catch {
            $_;
        }
    }
} 

#region Testing


        <#
        Write-Verbose "Exporting the result..."; 
        $exportPath = "$($env:SystemDrive)\hocs_temp\exported.tmp";
        Export-CliXml -InputObject $clusterSharedVolumes -Path $exportPath;
        $clusterSharedVolumesExportCopy = Import-CliXml -Path $exportPath;
        try {
            foreach ($storage in $clusterSharedVolumesExportCopy) {
                Write-Verbose "Working with csv $($storage.Name)";
                Add-Member -InputObject $storage -type NoteProperty -name "allDrives" -value "";
                $allDrives = $storage.vhdDrives;
                foreach ($drive in $allDrives) {
                    Write-Verbose "working with drive $drive...";
                    if ($drive.isPresentByThePath) {
                        $storage.allDrives += "vmName: $($drive.vmName)`n"
                        $storage.allDrives += "pathToDrive: $($drive.pathToDrive)`n"
                        $storage.allDrives += "isPresentByThePath: $($drive.isPresentByThePath)`n"
                        $storage.allDrives += "currentDriveSizeGB: $($drive.currentDriveSizeGB)`n"
                        $storage.allDrives += "allocatedDriveSizeGB: $($drive.allocatedDriveSizeGB)`n"
                        $storage.allDrives += "currentDriveSizeGBPercentOfCsvVolume: $($drive.currentDriveSizeGBPercentOfCsvVolume)`n"
                        $storage.allDrives += "allocatedDriveSizeGBPercentOfCsvVolume: $($drive.allocatedDriveSizeGBPercentOfCsvVolume)`n"
                        $storage.allDrives += "`n"
                    }
                    else {
                        $storage.allDrives += "vmName: $($drive.vmName)`n"
                        $storage.allDrives += "pathToDrive: $($drive.pathToDrive)`n"
                        $storage.allDrives += "isPresentByThePath: $($drive.isPresentByThePath)`n"
                        $storage.allDrives += "`n"
                    }
                }
                $storage.PSObject.Properties.Remove("vhdDrives");
                #also need to be able to transform array of the cluster storages into exportable object
            }
        }
        catch {
            $_;
        }
        $clusterSharedVolumesExportCopy | Export-Csv -Path "C:\hocs_temp\CSV_Storage_with_vhd_disks.csv" -NoTypeInformation;
        Remove-Item -Path $exportPath -Confirm;
        #>














        <#
        Write-Verbose "Exporting the result...";
        $exportCopy = $clusterSharedVolumes;
        try {
            foreach ($clusterStorage in $exportCopy) {
                Add-Member -InputObject $clusterStorage -type NoteProperty -name "allDrives" -value "";
                foreach ($drive in $clusterStorage.vhdDrives) {
                    if ($drive.isPresentByThePath) {
                        $clusterStorage.allDrives += "vmName: $($drive.vmName)`n"
                        $clusterStorage.allDrives += "pathToDrive: $($drive.pathToDrive)`n"
                        $clusterStorage.allDrives += "isPresentByThePath: $($drive.isPresentByThePath)`n"
                        $clusterStorage.allDrives += "currentDriveSizeGB: $($drive.currentDriveSizeGB)`n"
                        $clusterStorage.allDrives += "allocatedDriveSizeGB: $($drive.allocatedDriveSizeGB)`n"
                        $clusterStorage.allDrives += "currentDriveSizeGBPercentOfCsvVolume: $($drive.currentDriveSizeGBPercentOfCsvVolume)`n"
                        $clusterStorage.allDrives += "allocatedDriveSizeGBPercentOfCsvVolume: $($drive.allocatedDriveSizeGBPercentOfCsvVolume)`n"
                        $clusterStorage.allDrives += "`n"
                    }
                    else {
                        $clusterStorage.allDrives += "vmName: $($drive.vmName)`n"
                        $clusterStorage.allDrives += "pathToDrive: $($drive.pathToDrive)`n"
                        $clusterStorage.allDrives += "isPresentByThePath: $($drive.isPresentByThePath)`n"
                        $clusterStorage.allDrives += "`n"
                    }
                }
                #add removal of unnecessary $clusterStorage.vhdDrives filed somewhere here
                #also need to be able to transform array of the cluster storages into exportable object
            }
        }
        catch {
            $_;
        }

        #Fix 
        Export-Csv -InputObject $exportCopy[0] -Path "$($env:SystemDrive)\hocs_temp\Final_Cluster_storages_with_vhdx_drives1.csv" -NoTypeInformation;
        Export-Csv -InputObject $exportCopy[1] -Path "$($env:SystemDrive)\hocs_temp\Final_Cluster_storages_with_vhdx_drives2.csv" -NoTypeInformation;
        #>


        #$exportPath = "$($env:SystemDrive)\hocs_temp\exported.tmp";
        #Export-CliXml -InputObject $clusterSharedVolumes -Path $exportPath;
        #$clusterSharedVolumesExportCopy = Import-CliXml -Path $exportPath;


#? {$_.path -like 'C:\ClusterStorage\Volume2'} |
#$r = $clusterSharedVolumes | % {$_.vhdDrives | select -Property vmName, pathToDrive, currentDriveSizeGB}

#$vm_Info_Disk = $clusterSharedVolume | Select-Object {$_.vhdDrives | Select-Object -Property vmName, pathToDrive, currentDriveSizeGB}

function misc_files {
    [CmdletBinding()]
    param (
        $clusterSharedVolumes,
        $ErrorActionPreference = “silentlycontinue”
        )
    Write-Verbose "Getting info about miscellanious items on cluster storage(s)...";
    foreach ($clusterSharedVolume in $clusterSharedVolumes) {
        $miscellaniousItems = @();
        Add-Member -InputObject $clusterSharedVolume -type NoteProperty -name "misc_items" -value "";
        Add-Member -InputObject $clusterSharedVolume -type NoteProperty -name "misc_items_size_MB" -value "";
        Write-Verbose "`nWorking with $($clusterSharedVolume.path) path";
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            #Read-Host "Press Enter to continue";
        }
        Get-ChildItem -Path $($clusterSharedVolume.path) -File -Force -Recurse -Exclude "*.vhdx" -ErrorAction SilentlyContinue -OutVariable miscellaniousItems;
        Write-Verbose "`nFound $($miscellaniousItems.Count) miscellanious items";
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
            #read-host "Press Enter to continue";
        }
        foreach ($path in $miscellaniousItems) {
            try {
                $itemProperty = (Get-Item $path -Force -ErrorAction Inquire);
                $path = "$($itemProperty.FullName)`n";
                $size = "$($itemProperty.Length / 1mb)`n";
                $clusterSharedVolume.misc_items += $path;
                $clusterSharedVolume.misc_items_size_MB += $size;
                Write-Verbose "Item by path $path has size of $size MB";
            }
            catch {
                $_;
            }
        }
    }
    return 
}

        <#
        foreach ($clusterSharedVolume in $clusterSharedVolumes) {
            write-host "$($clusterSharedVolume.name):" -BackgroundColor Yellow -ForegroundColor Black;
            $clusterSharedVolume | Select-Object -ExcludeProperty vhdDrives -Property name, path, totalSizeGB, freeSpaceGB, usedSpaceGB, percentFree | Format-List;
            Write-Host "Drives on this CSV:";
            $clusterSharedVolume.vhdDrives | Format-List;
        }
        #>


#totalSizeBytes = $csv.SharedVolumeInfo.Partition.Size; 
#freeSpaceBytes = $csv.SharedVolumeInfo.Partition.FreeSpace; 
#usedSpaceBytes = $csv.SharedVolumeInfo.Partition.UsedSpace;

#currentDriveSizeBytes = ((get-vhd -Path $driveOfCurrentVM.Path).FileSize);
#allocatedDriveSizeBytes = ((get-vhd -Path $driveOfCurrentVM.Path).Size);


#$allFoundVHDDrives = @();
#get-vm | ForEach-Object {$allFoundVHDDrives += $_.HardDrives;}








function convert {
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        $clusterSharedVolumes
    )
    process {
        $exportPath = "$($env:SystemDrive)\hocs_temp\exported.tmp";
        Export-CliXml -InputObject $clusterSharedVolumes -Path $exportPath;
        $clusterSharedVolumesExportCopy = Import-CliXml -Path $exportPath;
        try {
            foreach ($storage in $clusterSharedVolumesExportCopy) {
                Write-Verbose "working with csv $storage"
                Add-Member -InputObject $storage -type NoteProperty -name "allDrives" -value "";
                $allDrives = $storage.vhdDrives;
                foreach ($drive in $allDrives) {
                    Write-Verbose "working with drive $drive"
                    if ($drive.isPresentByThePath) {
                        $storage.allDrives += "vmName: $($drive.vmName)`n"
                        $storage.allDrives += "pathToDrive: $($drive.pathToDrive)`n"
                        $storage.allDrives += "isPresentByThePath: $($drive.isPresentByThePath)`n"
                        $storage.allDrives += "currentDriveSizeGB: $($drive.currentDriveSizeGB)`n"
                        $storage.allDrives += "allocatedDriveSizeGB: $($drive.allocatedDriveSizeGB)`n"
                        $storage.allDrives += "currentDriveSizeGBPercentOfCsvVolume: $($drive.currentDriveSizeGBPercentOfCsvVolume)`n"
                        $storage.allDrives += "allocatedDriveSizeGBPercentOfCsvVolume: $($drive.allocatedDriveSizeGBPercentOfCsvVolume)`n"
                        $storage.allDrives += "`n"
                    }
                    else {
                        $storage.allDrives += "vmName: $($drive.vmName)`n"
                        $storage.allDrives += "pathToDrive: $($drive.pathToDrive)`n"
                        $storage.allDrives += "isPresentByThePath: $($drive.isPresentByThePath)`n"
                        $storage.allDrives += "`n"
                    }
                }
                $storage.PSObject.Properties.Remove("vhdDrives");
                #also need to be able to transform array of the cluster storages into exportable object
            }
        }
        catch {
            $_;
        }
        Remove-Item -Path $exportPath -Confirm;
        return $clusterSharedVolumesExportCopy
    }
}
        

#region Test data

$clusterSharedVolume = [pscustomobject][ordered]@{
    name = "CSV_Name";
    path = "C:\hocs_temp\storage2";
    totalSizeGB = 212.22;
    freeSpaceGB = 34.27;
    usedSpaceGB = 155.77;
    percentFree = 2.12;
    vhdDrives = @();
}

$clusterSharedVolume1 = [pscustomobject][ordered]@{
    name = "CSV_Name_new";
    path = "C:\hocs_temp\storage33";
    totalSizeGB = 512.22;
    freeSpaceGB = 74.8;
    usedSpaceGB = 955.77;
    percentFree = 2.12;
    vhdDrives = @();
}

$vhdDrive = [pscustomobject][ordered]@{ 
        vmName = "vmName";
        pathToDrive = "C:\path_to_drive\New";
        isPresentByThePath = $false;
        currentDriveSizeGB = 74.5;
        allocatedDriveSizeGB =  62.88;
        currentDriveSizeGBPercentOfCsvVolume = 42
        allocatedDriveSizeGBPercentOfCsvVolume = 8
}

$vhdDrive1 = [pscustomobject][ordered]@{ 
        vmName = "CoolVmName";
        pathToDrive = "C:\path_to_drive";
        isPresentByThePath = $true;
        currentDriveSizeGB = 664.5;
        allocatedDriveSizeGB =  4422.33;
        currentDriveSizeGBPercentOfCsvVolume = 76
        allocatedDriveSizeGBPercentOfCsvVolume = 5
}

$vhdDrive2 = [pscustomobject][ordered]@{ 
    vmName = "badVmName";
    pathToDrive = "F:\";
    isPresentByThePath = $false;
}

$clusterSharedVolume.vhdDrives += $vhdDrive;
$clusterSharedVolume.vhdDrives += $vhdDrive;
$clusterSharedVolume.vhdDrives += $vhdDrive1;

$clusterSharedVolume1.vhdDrives += $vhdDrive1;
$clusterSharedVolume1.vhdDrives += $vhdDrive;
$clusterSharedVolume1.vhdDrives += $vhdDrive2;

$clusterSharedVolumes = @();

$clusterSharedVolumes += $clusterSharedVolume
$clusterSharedVolumes += $clusterSharedVolume1
#endregion Test data

#$clusterSharedVolume.vhdDrives | %{"----"; Get-Member -InputObject $_ -MemberType NoteProperty; "========"}


foreach ($drive in $clusterSharedVolume.vhdDrives) { 
    $stringRepresentation = "";
    $members = Get-Member -InputObject $drive -MemberType NoteProperty
    foreach ($item in $members){
        $content = $item.Definition.split('=')
        $stringRepresentation += "$($content[0].split(' ')[1]) = $($content[1])`n"
    }
}



function getMembersOfObject {
    [CmdletBinding()]
    param(
        [Parameter()]
        $object
    )
    Write-Verbose "Starting to get properties..."
    foreach ($obj in $object) {
        $objProperties = Get-Member -InputObject $obj -MemberType NoteProperty
        foreach ($item in $objProperties) {
            if ($item.Definition.Contains("Object[]")) {
                $content = $item.Definition.split('=')
                $nestedObj = $obj.$($content[0].split(' ')[1])
                Write-Verbose "In recurse call for nested object $nestedObj...";
                $stringRepresentation += getMembersOfObject -object $nestedObj;
                if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
                    #read-host "Press Enter to continue";
                }
                
            }
            else {
                Write-Verbose "Working with item $($item)"
                $content = $item.Definition.split('=')
                Write-Verbose "Adding content $($content[0].split(' ')[1]) = $($content[1]) to string representation"
                $stringRepresentation += "$($content[0].split(' ')[1]) = $($content[1])`n";
                if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
                    #read-host "Press Enter to continue";
                }
            }
        }
    }
    return $stringRepresentation;
}

#endregion Testing