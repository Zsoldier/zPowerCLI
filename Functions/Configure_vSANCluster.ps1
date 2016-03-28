#Enable All Flash vSAN Intelligently
Add-PSSnapIn -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue
$TargetHosts = Get-VMHost
#$ESXCLI = $TargetHosts | Get-EsxCli
#$Storage = $Targethosts | Get-VMHostStorage
#$Storage.ScsiLun #List of Vendors and model
$CacheDiskVendor = "SanDisk"
$CacheDiskModel = "LT0400WM"
$CapacityDiskVendor = "SanDisk"
$CapacityDiskModel = "LT0800MO"
#$TargetHBA = "vmhba0"

# Example to tag a flash drive as capacity
#$esxcli.vsan.storage.tag("naa.6000c295be1e7ac4370e6512a0003edf","capacityFlash")
#Creates a disk group w/ two disks and one cache
#$ESXCLI.vsan.storage.add(@("naa.5001e882002837dac","naa.5001e82002837f08"),"naa.5001e82002850250")

Foreach ($VMhost in $TargetHosts)
    {
    $ESXCLI = $VMHost | Get-ESXCLI
    $Storage = $VMhost | Get-VMHostStorage
    Foreach ($SCSILUN in $Storage.ScsiLun)
        {
        If ($SCSILUN.Vendor -match $CapacityDiskVendor -and $SCSILUN.Model -match $CapacityDiskModel)
            {
            $VMHost.Name
            $ESXCLI.vsan.storage.tag.add($SCSILUN.CanonicalName,"capacityFlash")
            }
        }
    }


<#Creates Disk Groups#>
[System.Collections.ArrayList]$CapacityList = @()
[System.Collections.ArrayList]$CacheList = @()
Foreach ($VMHost in $targethosts)
    {
    $ESXCLI = $VMHost | Get-ESXCLI
    $Storage = $VMhost | Get-SCSILUN
    Foreach ($SCSILUN in $Storage)
        {
        If ($SCSILUN.Vendor -match $CapacityDiskVendor -and $SCSILUN.Model -match $CapacityDiskModel)
        {
        $CapacityList += $SCSILUN
        }
        If ($SCSILUN.Vendor -match $CacheDiskVendor -and $SCSILUN.Model -match $CacheDiskModel)
        {$CacheList += $SCSILUN}
        }
    $Ratio = ($CapacityList.Count / $CacheList.Count)
        <# Odd Number Checker
        If ($Ratio % 2 -eq 0) 
            {
            }
        #>
    Foreach ($CacheDisk in $CacheList)
        {$CapacityDiskList = @()
            Foreach ($Disk in ($CapacityList | select -first $Ratio))
                {
                $ESXCLI.vsan.storage.tag.add($Disk.CanonicalName,"capacityFlash")
                $CapacityDiskList += $Disk.CanonicalName
                }
            $ESXCLI.vsan.storage.add($CapacityDiskList,$CacheDisk.CanonicalName)
            $CapacityList.RemoveRange(0,$Ratio)
            }
    }
