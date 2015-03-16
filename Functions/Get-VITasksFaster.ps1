#Get-VIEventsFaster
#
Function Get-VITasksFaster
{[cmdletbinding()]
<#
  .SYNOPSIS
  Uses the PowerCLI Get-View cmdlet to query for tasks.
  .DESCRIPTION
  This is meant to make something a bit more robust for getting 'task' info.  Also so that you can use it to tie the Get-VIEvent cmdlet or Get-VIEventsFaster/Get-VIEventPlus functions to tasks info.
  .PARAMETER server
  Connects to vCenter or ESXi server specified.
  .PARAMETER start
  The beginning of the time range. If this property is not set, then events are collected from the earliest time in the database. 
  .PARAMETER finish
  The end of the time range. If this property is not specified, then events are collected up to the latest time in the database. 
  .PARAMETER timetype
  When start and/or finish dates are defined, the default lookup is against 'queuedTime'.  startedTime and completedTime are other valid values.
  .PARAMETER username
  The filter specification for retrieving tasks by user name. If not provided, then the tasks belonging to any user are collected. 
  .PARAMETER entity
  Looking for a vSphere object, VM, host, or otherwise. 
  .EXAMPLE
  $Date = Get-Date ; $Tasks = Get-VITasksFaster -Start ($Date.AddMonths(-1)) -Finish $Date
  Gets all tasks from 'exactly' 1 month ago to today and captures them in the $Tasks variable.  
  If Get-Date returned Friday, June 13, 2014 11:00:46 AM, one month ago would be Tuesday, May 13, 2014 11:00:46 AM.
  .LINK
  http://tech.zsoldier.com/
  https://github.com/Zsoldier/zPowerCLI
  #>
param (
	[Parameter(Mandatory=$False,HelpMessage="ESXi or vCenter to query events from.")]
	[VMware.VimAutomation.ViCore.Impl.V1.VIServerImpl]
	$Server,
	
	[Parameter(Mandatory=$False,HelpMessage="queuedTime is default. completedTime and startTime are also valid values.")]
	[string]
	$TimeType,
	
	[Parameter(Mandatory=$False,HelpMessage="Start Date to begin gathering tasks")]
	[DateTime]
	$Start,

	[Parameter(Mandatory=$False,HelpMessage="Last date to collect tasks up to.")]
	[DateTime]
	$Finish,
	
	[Parameter(Mandatory=$False,HelpMessage="Specifies the username list to use in the filter. If not set, then all regular user tasks are collected.")]
	[String[]]
	$UserName,
	
	[Parameter(Mandatory=$False,HelpMessage="Whether or not to filter by system user. If set to true, filters for system user event. Defaults to False.")]
	[boolean]
	$systemUser,

	[Parameter(Mandatory=$False,HelpMessage="Tag?")]
	[string]
	$Tag,

	[Parameter(Mandatory=$False,ValueFromPipeline=$True,HelpMessage="Looks for events associated w/ specified entity or entities")]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
	$Entity
	)
Begin 
	{
	$AllEvents = @()
	$tm = get-view -Server $Server TaskManager
	$TaskFilterSpec= New-Object VMware.Vim.TaskFilterSpec
	#VIServer
	If (!$Server)
	{
	If (!$global:DefaultVIServers){Write-Host "You don't appear to be connected to a vCenter or ESXi server." -ForegroundColor:Red; Break}
	$Server = $global:DefaultVIServers[0]
	}
	#UserName Filter
	If ($UserName -or $systemUser)
		{
		$TaskFilterSpec.UserName = New-Object VMware.Vim.TaskFilterSpecByUsername
		If ($systemUser)
			{
			$taskfilterspec.UserName.SystemUser = $systemuser
			}
		If ($UserName)
			{
			$taskfilterspec.UserName.UserList = $UserName
			}
		}
	#Time Filter
	If ($Start -or $Finish)
		{
		$TaskFilterSpec.Time = New-Object Vmware.Vim.TaskFilterSpecByTime
		If ($Start)
			{
			$TaskFilterSpec.Time.BeginTime = $Start
			}
		If ($Finish)
			{
			$TaskFilterSpec.Time.EndTime = $Finish
			}
		If ($TimeType)
			{
			$taskfilterspec.Time.TimeType = $TimeType
			}
		}
	#vSphere Object Filter
	If ($Entity)
		{
		$TaskFilterSpec.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
		$TaskFilterSpec.Entity.Recursion = "self"
		$TaskFilterSpec.Entity.Entity = $Entity.ExtensionData.MoRef
		}
	If ($Tag)
		{
		$TaskFilterSpec.Tag = $Tag
		}
	}
Process
	{
	#Query
	$tmCollector = Get-View -Server $server ($tm.CreateCollectorForTasks($TaskFilterSpec))
	$PageEvents = $tmCollector.ReadNextTasks(100)
	While ($PageEvents)
		{
		$AllEvents += $PageEvents
		$PageEvents = $tmCollector.ReadNextTasks(100)
		}
	$AllEvents
	}
End {$tmCollector.DestroyCollector()}
}
