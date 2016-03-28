#Enable All Flash vSAN Intelligently
Import-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue
$TargetHosts = Get-VMHost
#$ESXCLI = $TargetHosts | Get-EsxCli
#$Storage = $Targethosts | Get-VMHostStorage
#$Storage.ScsiLun #List of Vendors and model
$CacheDiskVendor = "SanDisk"
$CacheDiskModel = "LT0400WM"
$CapacityDiskVendor = "SanDisk"
$CapacityDiskModel = "LT0800MO"
#These below numbers are based upon vSAN 6.0 configuration maximums.
$DiskGroupMax = 5
$CapacityDiskMax = 7
#$TargetHBA = "vmhba0"

# Example to tag a flash drive as capacity
#$esxcli.vsan.storage.tag("naa.6000c295be1e7ac4370e6512a0003edf","capacityFlash")
#Creates a disk group w/ two disks and one cache
#$ESXCLI.vsan.storage.add(@("naa.5001e882002837dac","naa.5001e82002837f08"),"naa.5001e82002850250")

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
            {
            $CacheList += $SCSILUN
            }
        }
    If ($CacheList.Count -gt $DiskGroupMax) 
        {
        Write-Host "More than $($DiskGroupMax) Cache Disks were found. Script is exiting. vSAN only supports a max of $($DiskGroupMax) disk groups.  This script does not account for setups outside standards and also assumes different models of disks for cache and capacity.  Manual setup will be required."
        Break
        }
    $Ratio = ($CapacityList.Count / $CacheList.Count)
    If ($Ratio -gt $CapacityDiskMax)
        {
        Write-Host "More than $($CapacityDiskMax) capacity disks were found per disk group. Script is exiting. vSAN only supports a max of $($CapacityDiskMax) capacity disks per disk group.  This script does not account for setups outside standards.  Manual setup will be required."
        Break 
        }
    }
        <# Non-Integer Number Checker #>
        If ($Ratio.gettype() -eq [int32]) 
            {
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
        ElseIf ($Ratio.gettype() -eq [double])
            {
            $Ratio = [math]::ceiling($Ratio)    
            Foreach ($CacheDisk in $CacheList)
                {
                $CapacityDiskList = @()
                Foreach ($Disk in ($CapacityList | select -first $Ratio))
                    {
                    $ESXCLI.vsan.storage.tag.add($Disk.CanonicalName,"capacityFlash")
                    $CapacityDiskList += $Disk.CanonicalName
                    }
            $ESXCLI.vsan.storage.add($CapacityDiskList,$CacheDisk.CanonicalName)
            $CapacityList.RemoveRange(0,$Ratio)
            $CacheList.Remove($CacheDisk)
            $Ratio = ($CapacityList.count / $CacheList.count)
                }
            }
    }
