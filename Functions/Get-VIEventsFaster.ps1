#Get-VIEventsFaster
#
Function Get-VIEventsFaster
{
<#
  .SYNOPSIS
  Uses the PowerCLI Get-View cmdlet to query for events.
  .DESCRIPTION
  This is meant to replace the Get-VIEvent cmdlet in scripts for faster results w/o dramatic changes to code.
  .PARAMETER server
  Connects to vCenter or ESXi server specified.
  .PARAMETER start
  The beginning of the time range. If this property is not set, then events are collected from the earliest time in the database. 
  .PARAMETER finish
  The end of the time range. If this property is not specified, then events are collected up to the latest time in the database. 
  .PARAMETER type
  An array of event types can be specified as a filter.  See examples to see how to get a valid list of event types.
  .PARAMETER eventchainid
  The filter specification for retrieving events by chain ID. If the property is not set, events with any chain ID are collected. 
  .PARAMETER recurse
  If specified, gathers events for target object and it's children.  Otherwise, only events for the target object are gathered.
  .PARAMETER entity
  Looking for a vSphere object, VM, host, or otherwise. 
  .EXAMPLE
  $Date = Get-Date ; $Events = Get-VIEventsFaster -Start ($Date.AddMonths(-1)) -Finish $Date
  Gets all events from 'exactly' 1 month ago to today and captures them in the $Events variable.  
  If Get-Date returned Friday, June 13, 2014 11:00:46 AM, one month ago would be Tuesday, May 13, 2014 11:00:46 AM.
  .EXAMPLE
  $Date = Get-Date ; $Events = Get-VIEventsFaster -Start ($Date.AddMonths(-1)) -Finish $Date -Type "VmCreatedEvent","VmClonedEvent","VmDeployedEvent"
  Gets specified event types from 'exactly' 1 month ago to today and captures them in the $Events variable.  
  If Get-Date returned Friday, June 13, 2014 11:00:46 AM, one month ago would be Tuesday, May 13, 2014 11:00:46 AM.
  .EXAMPLE
  $Events | % {($_.gettype()).name} | select -Unique
  You can use this one liner to determine valid event 'types'
  .LINK
  http://tech.zsoldier.com/
  #>
param (
	[Parameter(Mandatory=$False,HelpMessage="ESXi or vCenter to query events from.")]
	[VMware.VimAutomation.ViCore.Impl.V1.VIServerImpl]
	$Server,

	[Parameter(Mandatory=$False,HelpMessage="Start date to begin gathering events")]
	[DateTime]
	$Start,

	[Parameter(Mandatory=$False,HelpMessage="Date to gather events up to.")]
	[DateTime]
	$Finish,

	[Parameter(Mandatory=$False,HelpMessage="Filter down to types of events")]
	[string[]]
	$EventType,
	
	[Parameter(Mandatory=$False,HelpMessage="Filter down to types of events")]
	[int]
	$EventChainID,
	
	[Parameter(Mandatory=$False,HelpMessage="A switch indicating if the events for the children of the Entity will be also be returned.  Example: Cluster is the parent of VMHosts")]
	[switch]
	$Recurse,
	
	[Parameter(Mandatory=$False,ValueFromPipeline=$True,HelpMessage="Looks for events associated w/ specified entity or entities")]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]
	$Entity
	)
Begin 
	{
	$AllEvents = @()
	$EventFilterSpec= New-Object VMware.Vim.EventFilterSpec
	#VIServer
	If (!$Server)
	{
	If (!$global:DefaultVIServers){Write-Host "You don't appear to be connected to a vCenter or ESXi server." -ForegroundColor:Red; Break}
	$Server = $global:DefaultVIServers[0]
	}
	#Type
	If ($EventType)
		{
		$EventFilterSpec.EventTypeID = $EventType
		}
	#Time
	If ($Start -or $Finish)
		{
		$EventFilterSpec.Time = New-Object Vmware.Vim.EventFilterSpecByTime
		If ($Start)
			{
			$EventFilterSpec.Time.BeginTime = $Start
			}
		If ($Finish)
			{
			$EventFilterSpec.Time.EndTime = $Finish
			}
		}
	
	#Entity
	If ($Entity)
		{
		$EventFilterSpec.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
		$EventFilterSpec.Entity.Recursion = &{if($Recurse){"all"}else{"self"}}
		$EventFilterSpec.Entity.Entity = $Entity.ExtensionData.MoRef
		}
	#EventChainID
	If ($EventChainID)
		{
		$eventfilterspec.EventChainId = $EventChainID
		}
	}
Process
	{
	#Query
	$em = get-view -Server $Server EventManager
	$evCollector = Get-View -Server $server ($em.CreateCollectorForEvents($EventFilterSpec))
	$PageEvents = $evCollector.ReadNextEvents(100)
	While ($PageEvents)
		{
		$AllEvents += $PageEvents
		$PageEvents = $evCollector.ReadNextEvents(100)
		}
	$AllEvents
	}
End {$evCollector.DestroyCollector()}
}
