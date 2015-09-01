#--------------------------------------------------------------------------------- 

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Description,

        [ValidateSet("APPLICATION_INSTALL","APPLICATION_UNINSTALL","DEVICE_DRIVER_INSTALL","MODIFY_SETTINGS","CANCELLED_OPERATION")]
        [System.String]
        $RestorePointType = 'APPLICATION_INSTALL',

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = 'Present'
    )

    #Get the latest status of system restore point.
    $LatestRestorePoint = Get-ComputerRestorePoint | Select-Object -Last 1

    $returnValue = @{
        Description = If($LatestRestorePoint.Description){$LatestRestorePoint.Description}Else{"None"}
        RestorePointType = If($LatestRestorePoint.RestorePointType){$LatestRestorePoint.RestorePointType}Else{"None"}
        Ensure = $Ensure
    }
    
    
    If($($Description -eq $LatestRestorePoint.Description) -and $($(ConvertRestorePointValue -RestoreType $RestorePointType) -eq $LatestRestorePoint.RestorePointType))
    {
        $returnValue.Ensure = "Present"
    }
    Else
    {
        $returnValue.Ensure = "Absent"
    }
    
    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Description,

        [ValidateSet("APPLICATION_INSTALL","APPLICATION_UNINSTALL","DEVICE_DRIVER_INSTALL","MODIFY_SETTINGS","CANCELLED_OPERATION")]
        [System.String]
        $RestorePointType = 'APPLICATION_INSTALL',

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = 'Present'
    )

    Switch($Ensure)
    {
        'Present'
        {
            If($PSCmdlet.ShouldProcess("$Description","Creating restore point"))
            {
                Try
                {
                    Write-Verbose "Creating a system restore point on the target computer."
                    Checkpoint-Computer -Description $Description -RestorePointType $RestorePointType
                }
                Catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose $ErrorMsg
                }
            }
        }

        'Absent'
        {

$Definition = @"
[DllImport ("Srclient.dll")]
public static extern int SRRemoveRestorePoint (int index);
"@
            $Assemblies = [AppDomain]::CurrentDomain.GetAssemblies() 
            $isExists = ($Assemblies | Foreach {$_.GetTypes()} | Where {$_.FullName -eq "SystemRestore.DeleteRestorePoint"}) -ne $null

            If (!$isExists)
            {
                Add-Type -memberDefinition $Definition -Name DeleteRestorePoint -NameSpace SystemRestore -PassThru
            }

            $RestorePoints = Get-ComputerRestorePoint | Where{$_.Description -eq "$Description" -and $_.RestorePointType -eq "$(ConvertRestorePointValue -RestoreType $RestorePointType)"}

            Foreach($RestorePoint in $RestorePoints)
            {
                If($PSCmdlet.ShouldProcess("$Description","Deleting restore point"))
                {
                    Try
                    {
                        Write-Verbose "Deleting the restore point."
                        [SystemRestore.DeleteRestorePoint]::SRRemoveRestorePoint($restorePoint.SequenceNumber) | Out-Null
                    }
                    Catch
                    {
                        Write-Verbose "Failed to remove the restore point."
                    }
                }    
            } 
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Description,

        [ValidateSet("APPLICATION_INSTALL","APPLICATION_UNINSTALL","DEVICE_DRIVER_INSTALL","MODIFY_SETTINGS","CANCELLED_OPERATION")]
        [System.String]
        $RestorePointType = 'APPLICATION_INSTALL',

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = 'Present'
    )

    #Get the output of Get-TargetResource function.
    $Get = Get-TargetResource -Description $Description -RestorePointType $RestorePointType

    Switch($Ensure)
    {
        'Present'
        {
            #If the value of $Get.Ensure is "Present", it indicates that the current restore point is the same as the accepted value.
            If($Get.Ensure -eq "Present")
            {
                return $true
            }
            Else
            {
                return $false
            }
        }
        'Absent'
        {
            If($Get.Ensure -eq "Present")
            {
                return $false
            }
            Else
            {
                return $true
            }
        }
    }
}


Function ConvertRestorePointValue
{
    Param
    (
        $RestoreType
    )

    Switch($RestoreType)
    {
        "APPLICATION_INSTALL"
        {
            $Value = 0
        }
        "APPLICATION_UNINSTALL"
        {
            $Value = 1
        }
        "DEVICE_DRIVER_INSTALL"
        {
            $Value = 10
        }
        "MODIFY_SETTINGS"
        {
            $Value = 12
        }
        "CANCELLED_OPERATION"
        {
            $Value = 13
        }
    }
    return $Value
}


Export-ModuleMember -Function *-TargetResource
