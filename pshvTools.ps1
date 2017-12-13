function Read-VMwareVMtoHostConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputCSV)

    #Does input CSV exist.
    if ((Test-Path $InputCSV) -eq $false ) {Write-warning "$InputCSV does not exist" -ErrorAction SilentlyContinue; break}
    $Rules = Import-Csv $InputCSV
    Foreach ($Rule in $Rules)
    {
        $VMS = $Rule.VM
        $Hosts = $Rule.Host
        $Types = $Rule.Type

        switch ($Types)
        {
            Host
            {
                Write-Verbose "vMotion $VMS to $Hosts - Applying rule type $Types"
                Get-VM $VMS -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false | Move-VM -Destination (Get-VMHost $Hosts -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false) -RunAsync -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false |  Out-Null
            }
            Affinity
            {
                $VMS=$VMS.split(";")
                foreach ($VM in $VMS)
                {

                    Write-Verbose "vMotion $VM to $Hosts - Applying rule type $Types"
                    Get-VM $VM -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false | Move-VM -Destination (Get-VMHost $Hosts-InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false) -RunAsync -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false |  Out-Null
                }
            }
            AntiAffinity
            {
                $VMS=$VMS.split(";")
                $Hosts=$Hosts.split(";")
                $i = 0
                if ($VMS.Count -eq $Hosts.count) {

                    Foreach ($ESXHost in $Hosts)
                    {
                        $VM = $VMS | Select-Object -First 1  -Skip $i
                        Write-Verbose "vMotion $VM to $ESXHost - Applying rule type $Types"
                        Get-VM $VM  -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false | Move-VM -Destination (Get-VMHost $ESXhost -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false) -RunAsync  -InformationAction SilentlyContinue -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -Verbose:$false |  Out-Null
                        $i++
                    }
                }
            }
        }
    }
}

function Write-VMwareVMtoHostConfiguration {
    [CmdletBinding()]
    # Applies settings that are specified in the InputCSV file
    param([Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputCSV)

    #Does input CSV exist.
    if ((Test-Path (Split-Path -Path $OutputCSV)) -eq $false ) {Write-warning "$(Split-Path -Path $OutputCSV) does not exist" -ErrorAction SilentlyContinue; break}

    #Getting all VM's and Hosts they reside on.
    $CSVOut = Get-VM |   Select-Object @{Name="Host";Expression={$_."VMHost"}} , @{Name="VM";Expression={$_."Name"}}

    #Making the output standard so we can apply it with Set-pmDRSRules
    $CSVOut | Add-Member -membertype NoteProperty -name "Type" -value "Host"

    Write-Verbose "Writing VM-to-Host Settings file at $OutputCSV"
    #Write-Output $CSVOut
    $CSVOut | Export-CSV -NoTypeInformation -Path $OutputCSV 
}

Import-Module VMware.VimAutomation.Core -ErrorAction SilentlyContinue | Out-Null

#getting script path
$ScriptPath = (Split-Path ((Get-Variable MyInvocation).Value).MyCommand.Path)
#$ScriptPath = "C:\temp"

#SET THE FOLLOWING PARAMETERS TO $null if you want the script to prompt you for information
$user = "administrator@vsphere.local"
$server = "vcsa.lab.local"


#Securely storing password for vcenter
$CredsPath = $ScriptPath + "\creds_vc.txt"
$Creds = Test-Path $CredsPath

if ($Creds -eq $true)
{
    $password = Get-Content -Path $CredsPath | ConvertTo-SecureString 
}
else
{
    $password = read-host -AsSecureString “Enter your vCenter password: ”
    $password | ConvertFrom-SecureString | Out-File $CredsPath
}

$mycreds = New-Object System.Management.Automation.PSCredential ($user, $password)

Connect-VIServer $server -Credential $mycreds
Read-VMwareVMtoHostConfiguration -InputCSV  "C:\temp\server.csv" -Verbose
Write-VMwareVMtoHostConfiguration -OutPutCSV "C:\temp\server.csv" -Verbose
Disconnect-VIServer
