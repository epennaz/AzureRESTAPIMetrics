# ***********************************************************************
# * DISCLAIMER:
# *
# * All sample code is provided by OSIsoft for illustrative purposes only.
# * These examples have not been thoroughly tested under all conditions.
# * OSIsoft provides no guarantee nor implies any reliability,
# * serviceability, or function of these programs.
# * ALL PROGRAMS CONTAINED HEREIN ARE PROVIDED TO YOU "AS IS"
# * WITHOUT ANY WARRANTIES OF ANY KIND. ALL WARRANTIES INCLUDING
# * THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY
# * AND FITNESS FOR A PARTICULAR PURPOSE ARE EXPRESSLY DISCLAIMED.
# ************************************************************************


#Helpful websites:
#Credit to function Get-AzureRestAPIVMMetrics at: http://blogs.technet.com/b/learningittogether/archive/2014/10/27/using-rest-api-from-powershell-to-get-additional-azure-vm-status-details.aspx
#Explanation of Rest API Performance Counters:
#https://convective.wordpress.com/2014/06/22/using-azure-monitoring-service-with-azure-virtual-machines/


#SCRIPT TESTED VERSIONS:
#$PSVersionTable
#Name                           Value                                             
#----                           -----                                             
#PSVersion                      4.0                                               
#WSManStackVersion              3.0                                               
#SerializationVersion           1.1.0.1                                           
#CLRVersion                     4.0.30319.34209                                   
#BuildVersion                   6.3.9600.17090                                    
#PSCompatibleVersions           {1.0, 2.0, 3.0, 4.0}                              
#PSRemotingProtocolVersion      2.2 

#Import-Module Azure
#Get-Module Azure
#ModuleType Version    Name                                     
#---------- -------    ----                                  
#Manifest   0.9.1   Azure 

#PI AF Developer tools 2.6.0.5843

function Get-AzureRestAPIVMMetrics
{
<#
.SYNOPSIS
	tbd.
.DESCRIPTION
	tbd.
#>
    [CmdletBinding()]
    param(
		[parameter(Mandatory=$true)]
		[string]
		$subscriptionName,
		[parameter(Mandatory=$true)]
		[string]
		$subscriptionID,
        [parameter(Mandatory=$true)]
		$azureVM,
	    [parameter(Mandatory=$true)]
		[string]
		$myHourStart,
	    [parameter(Mandatory=$true)]
		[string]
		$myHourEnd,
		[parameter(Mandatory=$true)]
		[string]
		$timeGrain
	)

    BEGIN 
    {
    }

    PROCESS
    {
        #get the current time
        $myDateObj = Get-Date

        #Get the time you want to query for and change it to Azure readable format ex: 2015-03-24T16:47:19.5421534Z
        $strDateStart= $myDateObj.AddHours($myHourStart).ToUniversalTime().ToString("o")
        $strDateEnd = $myDateObj.AddHours($myHourEnd).ToUniversalTime().ToString("o")
       
        #Add the query names for the VM name and Service name to fill out the uri to make a request from
        $azurevmName = $azureVM.Name
        $vmServiceName = $azureVM.ServiceName

        # API method
        #Comma Separated Metrics List
        $metricsList = 'Disk Read Bytes/sec,Disk Write Bytes/sec,Network Out,Percentage CPU,Network In'
        $deploymentName = $azurevm.DeploymentName 

        if (!$subscriptionID){$subscriptionID = (Get-AzureSubscription | Where-Object IsDefault).SubscriptionId}

        $account = Get-AzureAccount | Where-Object { $_.Subscriptions.Contains($subscriptionID) -and $_.Type -eq "Certificate" } 
            
        if (!$account){throw "Can't find an account for Azure subscription $subscriptionID"}
    
        $certificate = ls Cert:\CurrentUser\My | Where-Object Thumbprint -eq $account.Id

        if (!$certificate)
        {
            throw "Can't find the certificate for Azure account {0}" -f $account.Id
        }
            
        $uri = "https://management.core.windows.net/${SubscriptionId}/services/monitoring/metricvalues/query?resourceId=/hostedservices/${vmServiceName}/deployments/${deploymentName}/roles/${azurevmName}&namespace=&names=${metricsList}&timeGrain=${timeGrain}&startTime=${strDateStart}&endTime=${strDateEnd}"
          
        try
        {
            $response = Invoke-WebRequest -Method GET -Uri $uri -Certificate $certificate -Headers @{ "x-ms-version" = "2013-10-01" } -ErrorAction Ignore
        }
        catch
        {
            $message = ([xml] $_.ErrorDetails.Message)
            throw "{0}: {1}" -f $message.Error.Code, $message.Error.Message
        }
            
        $content = [xml] $response.Content
        Write-Output $content
}

    END
    {
    }
}

function Set-AzureRestAPIVMMetrics
{
<#
.SYNOPSIS
	tbd.
.DESCRIPTION
	tbd.
#> 
[CmdletBinding()]
    param (
            [Parameter(Mandatory = $true, ValueFromPipeline=$true)]
            $content,
            [Parameter(Mandatory = $true)]
            [String]
            $subscriptionName,
            [Parameter(Mandatory = $true)]
            [String]
            $subscriptionID,
            [Parameter(Mandatory = $true)]
            $azureVM
            )

   
    BEGIN
    { 
    }
    
    PROCESS
    {
        # Load AFSDK
        [System.Reflection.Assembly]::LoadWithPartialName("OSIsoft.AFSDKCommon") | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName("OSIsoft.AFSDK") | Out-Null

        # Create PI Object
        $PIDataArchives=New-object 'OSIsoft.AF.PI.PIServers'
        $PIDataArchive=$PIDataArchives.DefaultPIServer

        # Create AF UpdateOption
        $AFUpdateOption = New-Object 'OSISoft.AF.Data.AFUpdateOption'
        #Set AF Update Option to Replace
        $AFUpdateOption.value__ = "0"

        # Create AF BufferOption
        $AFBufferOption = New-Object 'OSISoft.AF.Data.AFBufferOption'
        #Set AF Buffer Option to Buffer if Possible
        $AFBufferOption.value__ = "1"

        #Create AF Recorded Value
        $AFRecordedValue = New-Object 'OSIsoft.AF.Data.AFBoundaryType'
        #Set AF recorded Value option to Inside
        $AFRecordedValue.value__ = "0"   

        $vmName = $azureVM.Name

        #Set a more friendly variable for parsing tag,timestamp,value
        $metricValuesSet = $content.MetricValueSetCollection.value.Metricvalueset

        #Create the Attributes for Metrics
        #Order: 'Disk Read Bytes/sec,Disk Write Bytes/sec,Network Out,Percentage CPU,Network In'
        for($i=0; $i -lt  $metricValuesSet.Count; $i++)
        {  
        #Metrics Displayed in their full glory
        $metricName = $metricValuesSet[$i].Name
        $metricValuesTimeStamps = $metricValuesSet[$i].MetricValues.Metricvalue.Timestamp
        $metricValues = $metricValuesSet[$i].MetricValues.MetricValue.Average
            
        #other Metrics Available
        #$metricMinimum   = $metricValues[$i].Minimum
        #$metricMaximum   = $metricValues[$i].Maximum
        #$metricTotal     = $metricValues[$i].Total

        # Assign Tag Name to the PI Point
        $tagName = $subscriptionID + '_' + $vmName + '_' + $metricName #e.g. $tagname = "Testing"
                  
        #Create the PI Point associated with that attribute
		$piPoint = $null
        if([OSIsoft.AF.PI.PIPoint]::TryFindPIPoint($PIDataArchive,$tagName,[ref]$piPoint) -eq $false)
		{ 
            $piPoint = $piDataArchive.CreatePIPoint($tagName) 
            $pipoint.SetAttribute("Descriptor", "Machine Size: " + $azureVM.vm.rolesize)
        }			

        #Manipulate TimeStamp String to output something friendly for AF to input
		#example $timestamp = "2015-03-05T18:17:43.943Z"
		$timestamp = @(); foreach($tsz in $metricValuesTimeStamps) { $timestamp += ([Datetime]::Parse(($tsz -replace "Z",""))) }
			
        $recordedValues = New-Object 'Collections.Generic.List[OSIsoft.AF.Asset.AFValue]'
            
		for($j=0; $j -lt $timestamp.Count; $j++)
		{
			# Instantiate a new 'AFValue' object to persist...				
			$newValue = New-Object 'OSIsoft.AF.Asset.AFValue'

			# Fill in the properties.
			$newValue.Timestamp = New-Object 'OSIsoft.AF.Time.AFTime'($timestamp[$j])
               
            $newValue.pipoint = $pipoint
			$newValue.Value = $metricValues[$j]

			# Add to collection.
			$recordedValues.Add($newValue)	
		}

        #Update the PI Point Values.
        try
        {
            $piPoint.UpdateValues($recordedValues,$AFUpdateOption)
        }
        catch
        {
            $message = ($_.ErrorDetails.Message)
            throw "{0}: {1}" -f $message.Error.Code, $message.Error.Message 
        }
        
       }
   
     }
        #Disconnect from the AF Server
        #$PISystem.Disconnect()

        # Disconnect from the PI Data Archive
        #$PIDataArchive.Disconnect()
    
    END
    {
    }
   
}


#Set the Azure Subscription to the current one
$subscriptionName = 'XXXXXXX' #Enter the name of your Subscription
$subscription = Get-AzureSubscription -SubscriptionName $subscriptionName
$subscriptionID = $subscription.SubscriptionID

#Retrieve all of the VMs and loop through them for individual output
$azureVMs = Get-AzureVM
  
#Rollup Time Grain, PT5M = 5-minute rollup; PT1H = 1-hour rollup; P1D = 1-day rollup; P7D = 7-days rollup;
#Get and Set the Azure Metrics
#Azure performance counters for the last timegrain (e.g. 5 mins, 1 hour) may not be immediately available, so go back one or two timeframes.
#Based on initial testing, past 36 days (864 hours) are kept on the hypervisors. 

#In this example, we do the from *-4H to *-1H

ForEach($azureVM in $azureVMs) 
{
#Check to see if it's StoppedDeallocated, then we don't care - break the loop.
if($azureVM.Status -eq 'StoppedDeallocated'){continue}
#Now, Get and Set the Metrics
Get-AzureRestAPIVMMetrics `
    -subscriptionName $subscriptionName `
    -subscriptionID $subscriptionID `
    -azureVM $azureVM `
    -myHourStart '-4' `
    -myHourEnd '-1' `
    -timeGrain 'PT5M' |`
Set-AzureRestAPIVMMetrics `
    -subscriptionName $subscriptionName `
    -subscriptionID $subscriptionID `
    -azureVM $azureVM 
}




