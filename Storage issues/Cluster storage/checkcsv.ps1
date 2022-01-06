Import-Module C:\Windows\system32\WindowsPowerShell\v1.0\Modules\FailoverClusters\FailoverClusters.psd1

$objs = @()

$csv_status = Get-ClusterSharedVolume
foreach ( $csv in $csv_status )
{
   $expanded_csv_info = $csv | select -Property Name -ExpandProperty SharedVolumeInfo
   foreach ( $csvinfo in $expanded_csv_info )
   {
      $obj = New-Object PSObject -Property @{
         Name        = $csvinfo.Name
         Path        = $csvinfo.FriendlyVolumeName
         Size        = $csvinfo.Partition.Size
         FreeSpace   = $csvinfo.Partition.FreeSpace
         UsedSpace   = $csvinfo.Partition.UsedSpace
         PercentFree = $csvinfo.Partition.PercentFree
      }
      if ($csvinfo.Partition.PercentFree -lt $warninglevel) { $objs += $obj }
   }
   $objs += $obj
}
$obj