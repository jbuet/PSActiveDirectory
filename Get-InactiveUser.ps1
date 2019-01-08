
<#
    .SYNOPSIS
        Get-InactiveUser - Search for inactive users in an Active Directory domain
            
    .DESCRIPTION
        Perform a search on a domain to retrieve inactive users for a number of days. 
        It allows you to output the results to screen or to a CSV File.

    .OUTPUTS
        Results are output to screen, as well as optional CSV File.
        
    .PARAMETER DomainController
        Name of Domain Controller server to use to the search.

    .PARAMETER Credential
        Allows you to specify credentials to execute the Active Directory commands.

    .PARAMETER SearchBase
        Allows you to specify the Organization Unit to search for inactive users.

    .PARAMETER InactiveDay
        Number of days of inactive users to search for. 
        The default value is 60 days.

    .PARAMETER FilePath
        Allows you to specify a path to output the results to a CSV file.

    .EXAMPLE
        Get-InactiveUser 
        Retrieve computer objects that have been inactive for more than 60 days 
    
    .EXAMPLE
        Get-InactiveUser -InactiveDay 30 | Format-Table
        Retrieve User objects that have been inactive for more than 60 days 

    .EXAMPLE
        Get-InactiveUser -FilePath "$Env:userprofile\Desktop\InactiveUser.csv"
        Generate a CSV file with user objects that have been inactive for more than 30 days.


    .EXAMPLE
        Get-InactiveUser -InactiveDay 360 | Where-Object {$_.Enabled} | select-Object -ExpandProperty samaccountname  | Disable-ADAccount -Verbose
        Disable all user objects that have been inactive for more than 360 days.

    .LINK
        https://github.com/jbuet/PSActiveDirectory
    

    .NOTES
        Requirements: 
            ActiveDirectory Module

#>
#Requires -Module ActiveDirectory

[CmdletBinding()]
param (
    [Alias('cn', 'Server')]
    [String]
    $DomainController,

    [pscredential]
    $Credential,

    [String]
    $SearchBase,

    [Int]
    $InactiveDay = 60,

    [String]
    $FilePath

)

begin {
    # Powershell v2
    Import-Module ActiveDirectory -Verbose:$false
    Write-Verbose "[BEGIN  ] Starting $($MyInvocation.MyCommand) "

} # Begin


process {
    $time = (Get-Date).AddDays( - ($InactiveDay))
    $Arguments = @{
        Filter      = {LastLogonTimeStamp -lt $Time }
        Properties  = "SamAccountName", "LastLogonTimeStamp", "enabled"
        ErrorAction = "Stop"
    }
    
    switch ($PSBoundParameters.keys) {
        'DomainController' {
            if ($DomainController -ne $env:COMPUTERNAME -and $DomainController -ne 'localhost') {
                $Arguments.Server = $DomainController
            }
        } 

        'Credential' {
            $Arguments.Credential = $Credential
        }

        'SearchBase' {
            $Arguments.SearchBase = $SearchBase
        }
        
    } # Switch
    
    try {
            
        Write-Verbose "[PROCESS] Retrieving users"
        $Users = Get-ADUser @Arguments

        # Create Array
        $ArrayObjects = New-Object System.Collections.Generic.List[System.Object]
        
        $i = 0
        Write-Verbose "[PROCESS] Processing users"
        Foreach ($User in $Users) {
            $i ++
            $Percent = [Math]::Round(($i / $users.count * 100))
            Write-Progress -Activity "Processing users" -Status "Progress --> $Percent%" -PercentComplete  $Percent
            
            $Parameter = @{
                SamAccountName = $User.samaccountname
                LastLogon      = [DateTime]::FromFileTime($User.lastlogontimestamp).ToString('yyyy-MM-dd')
                Enabled        = $User.Enabled
            }
            
            $Object = New-Object PSObject -Property $Parameter
            
            #  avoid users that haven't logged on
            if ($object.lastlogon -ne '1600-12-31') {
                $ArrayObjects.Add($Object)
            } # IF
            
        } # foreach
            
        if ($ArrayObjects.count -gt 0) {

            if ($PSBoundParameters.ContainsKey('FilePath')) {
                try {
                        
                    Write-Verbose "[PROCESS] Generating CSV File"
                    $ArrayObjects | export-csv -NoTypeInformation -Path $FilePath -Encoding Unicode
                    Write-Verbose "[PROCESS] File generate: $FilePath"
                }
                catch {
                        
                    Write-Warning "Couldn't export to file"
                        
                } # try catch
            }
            else {
                Write-Verbose "[PROCESS] Exporting results to $DestinationPath"
                $ArrayObjects 
            }  # if else output options
        }
        else { 
            Write-Warning "Not found any inactive users"
        }  # if else check objects
    }  # try
    catch {

        Write-Error $_

    } # catch

} # process

end {

    Write-Verbose "[END   ] Ending $($MyInvocation.MyCommand)"

} # end