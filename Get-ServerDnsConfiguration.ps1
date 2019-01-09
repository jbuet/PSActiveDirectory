<#
    .SYNOPSIS
            
    .DESCRIPTION

    .OUTPUTS
        Results are output to screen.
        
    .PARAMETER ComputerName
        Name of computer to retrieve information.

    .PARAMETER Credential
        Allows you to specify credentials to execute the Active Directory commands.

    .EXAMPLE

    .EXAMPLE

    .LINK
        https://github.com/jbuet/PSActiveDirectory
        
        
    .NOTES
        https://github.com/jbuet/PSActiveDirectory
        Requirements:
            * At least Powershell 4.0
            * Target computers need to have enabled PSRemoting with the following command: winrm /qc


#>
[CmdletBinding()]

param (
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('CN', 'Server')]
    [String[]]
    $ComputerName = $Env:COMPUTERNAME, 

    [pscredential]
    $Credential
)

begin {

    Write-Verbose "[BEGIN  ] Starting $($MyInvocation.MyCommand) "

} # begin

process {
    $i = 0
    Write-Verbose "[PROCESS] Checking servers"
    $ArrayObjects = New-Object System.Collections.Generic.List[System.Object]

    Foreach ($Computer in $ComputerName) {
        try {
            $i ++
            $Percent = [Math]::Round(($i / $ComputerName.count * 100))
            Write-Progress -Activity "Processing computer: $Computer" -Status "Progress --> $Percent%"  -PercentComplete  $Percent
        
            Write-Verbose "[PROCESS] Retrieving information from $Computer"

            $Parameters = @{
                ErrorAction  = "Stop"
                Class        = "Win32_NetworkAdapterConfiguration"
                ComputerName = $Computer
            }

            IF ($Computer -match "Localhost|$($env:computername)") {
                $Parameters.remove("ComputerName")
            }
            elseif ($PSBoundParameters.ContainsKey("Credential")) {
                $Parameters.credential = $Credential
            } # if

            IF (Test-NetConnection -ComputerName $Computer -InformationLevel Quiet -WarningAction  SilentlyContinue ) {

                $NetworkComputer = Get-WmiObject @Parameters | Where-Object DNSServerSearchOrder
            
                $Property = @{
                    ComputerName         = $Computer
                    IPAddress            = $NetworkComputer.IpAddress -join "; "
                    NetworkAddress       = $NetworkComputer.Description
                    DHCPServer           = $NetworkComputer.DHCPServer
                    Subnet               = $NetworkComputer.IpSubnet -join "; "
                    DefaultGateway       = $NetworkComputer.DefaultIPGateway -join "; "
                    DNSServerSearchOrder = $NetworkComputer.DNSServerSearchOrder -join '; '
                } # property
                
                $Object = New-Object PSObject -Property $Property
                $ArrayObjects.Add($Object)  
            }
            else {
                Write-Warning "Computer $Computer does not respond to ping."
                Continue
            }
        }
        catch {

            Write-Warning "Access Denied: Computer $Computer. Check WinRm"

        } # try Catch
    } # foreach computer

    if ($ArrayObjects.Count -gt 0) {
        Write-Output $ArrayObjects
    }
    else {

        Write-Warning "Could not retrieve any information of the server"

    } # if else array count
}  # process

end {

    Write-Verbose "[END   ] Ending $($MyInvocation.MyCommand)"

} # end