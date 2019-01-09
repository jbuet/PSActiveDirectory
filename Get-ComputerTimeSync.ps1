<#
    .SYNOPSIS
    Get-ComputerTimeSync - Retrieve Time syncronization of a computer

    .DESCRIPTION
    This cmdlet retrieve time syncronization information of computers joined on a domain. Useful to check domain controllers configuration.

    .PARAMETER ComputerName
    Name of remote computer to retrieve time sync information.

    .PARAMETER Credential
    Credential to access remote computers.

    .EXAMPLE
    Get-ComputerTimeSync -Verbose
    Retrieve local time sync information of the computer.

    .EXAMPLE
    Get-ComputerTimeSync -ComputerName (Get-ADDomainController -Filter * | select -expand name) -Verbose
    Retrieve time syncronization information of all domain controllers of the domain.
    
    .LINK
        https://github.com/jbuet/PSActiveDirectory
    
    .NOTES
    Requiriments:
        * Target computers need to have enable PSRemoting with the following command: winrm /qc
        * Local admin permission on target computers
#>


#requires -RunAs
[CmdletBinding()]

param 
(
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias("Server", "CN")]
    [String[]]
    $ComputerName = $Env:COMPUTERNAME,

    [PSCredential]
    $Credential
)

begin {

    Write-Verbose "[BEGIN  ] Starting $($MyInvocation.MyCommand) "

} 

process {
    $i = 0
    Write-Verbose "[PROCESS] Checking sync time servers"
    $ArrayObjects = New-Object System.Collections.Generic.List[System.Object]

    foreach ($Computer in $ComputerName) {
        $i ++
        $Percent = [Math]::Round(($i / $ComputerName.count * 100))
        Write-Progress -Activity "Processing computer: $Computer" -Status "Progress --> $Percent%"  -PercentComplete  $Percent
        
        Write-Verbose "[PROCESS] Retrieving information from $Computer"
        IF (Test-NetConnection -ComputerName $Computer -InformationLevel Quiet -WarningAction  SilentlyContinue ) {
            
            $Parameters = @{
                Command      = {w32tm.exe /query /source}
                ComputerName = $Computer
                ErrorAction  = "Stop"
            }
            
            IF ($Computer -match "Localhost|$($env:computername)") {
                $Parameters.remove("ComputerName")
            }
            elseif ($PSBoundParameters.ContainsKey("Credential")) {
                $Parameters.credential = $Credential
            } # if

            try {

                $Source = Invoke-Command @Parameters
                
                $Parameters.Command = {w32tm.exe /query /configuration}
                $Configuration = Invoke-Command @Parameters
                
                $Procotol = ($Configuration | findstr.exe "Type:") -replace "^Type: (.*)$", '$1'
                
                $Property = @{
                    ComputerName = $Computer;
                    Source       = $Source;
                    Status       = "ON"
                    Protocol     = $Procotol
                }

                if ($Source | findstr.exe "0x80070426" ) {
                    $Property.Status = "Time service not Running"
                    $Property.Source = $Null
                    $Property.Protocol = $Null
                }
                                                            
            }
            catch {
                Write-Warning "Access denied at $Computer. Check winrm /qc"
                # ACCESS DENIED ERROR W32tm
                $Property = @{
                    ComputerName = $Computer;
                    Source       = $Null;
                    Status       = "Access Denied"
                    Procotol     = $Null
                }
            } # try catch
        }
        else {
            $Property = @{
                ComputerName = $Computer;
                Source       = $Null;
                Status       = "OFF"
                Procotol     = $Null
            }
        }
        $Object = New-Object PSObject -Property $Property
        $ArrayObjects.Add($Object)
    } # foreach

    Write-Verbose "[PROCESS] Outputting results"
    Write-Output $ArrayObjects 

} # process

end {

    Write-Verbose "[END   ] Ending $($MyInvocation.MyCommand)"

} # end