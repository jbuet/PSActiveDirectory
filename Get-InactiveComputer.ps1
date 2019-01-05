<#
    .SYNOPSIS
        Get-InactiveComputer - Search for inactive computers on your domain
            
    .DESCRIPTION
        Perform a search on a domain to retrieve inactive computers for a number of days. 
        It allows you to output the results to screen or to a CSV File.

    .OUTPUTS
        Results are output to screen, as well as optional CSV File.
        
    .PARAMETER DomainController
        Name of Domain Controller server to use to the search.

    .PARAMETER Credential
        Allows you to specify credentials to execute the Active Directory commands.

    .PARAMETER SearchBase
        Allows you to specify the Organization Unit to search for inactive computers.

    .PARAMETER InactiveDay
        Number of days of inactive computers to search for. 
        The default value is 30 days.

    .PARAMETER FilePath
        Allows you to specify a path to output the results to a CSV file.

    .EXAMPLE
        Get-InactiveComputer
        Retrieve computer objects that have been inactive for more than 30 days 
    
    .EXAMPLE
        Get-InactiveComputer -InactiveDay 60 | Format-Table
        Retrieve computer objects that have been inactive for more than 60 days 

    .EXAMPLE
        Get-InactiveComputer -FilePath "$Env:userprofile\Desktop\InactiveComputers.csv"
        Generate a CSV file with computer objects that have been inactive for more than 30 days.


    .EXAMPLE
        Get-InactiveComputer -InactiveDay 360 | Where-Object {$_.Enabled} | select-Object -ExpandProperty samaccountname  | Disable-ADAccount -Verbose
        Disable all computer objects that have been inactive for more than 360 days.

    .LINK
        https://github.com/jbuet/PSActiveDirectory
    

    .NOTES
        Requiere el modulo ActiveDirectory

#>


#Requires -Module ActiveDirectory
[CmdletBinding()]
param (

    [Alias('Server')]
    [String]
    $DomainController,

    $Credential ,

    [String]
    $SearchBase,
    
    [Int]
    $InactiveDay = 30, 

    [String]
    $FilePath

) # param

begin {
    Import-Module ActiveDirectory -Verbose:$false
    Write-Verbose "[BEGIN  ] Starting $($MyInvocation.MyCommand)"

} # begin

process {

    $time = (Get-Date).AddDays( - ($InactiveDay))
    $Arguments = @{
        ErrorAction = 'Stop'
        Filter      = {LastLogonTimeStamp -lt $Time }
        Properties  = 'LastLogonTimeStamp', 'enabled', 'operatingsystem', 'ipv4address'
    }
    
    switch ($PSBoundParameters.keys) {
        
        'ComputerName' {
            if ($computerName -ne $env:COMPUTERNAME -and $ComputerName -ne 'localhost') {
                $Arguments.Server = $ComputerName
            }
        }
        
        'Credential' {
            $Arguments.Credential = $Credential
        } 
        
        'SearchBase' {
            $Arguments.SearchBase = $SearchBase
        }

    } # Switch
    
    # Retrieve computers comparing last logon 
    try {
        
        Write-Verbose "[PROCESS] Retrieving computers"
        $LastLogon = Get-ADComputer @Arguments 
        
        # Create Array
        $OldMachine = New-Object System.Collections.Generic.List[System.Object]
        
        foreach ($computer in $LastLogon) {
            
            $Properties = @{
                Name               = $computer.Name
                Enabled            = $Computer.Enabled
                LastLogonTimeStamp = [DateTime]::FromFileTime($computer.lastLogonTimestamp).ToString('yyyy-MM-dd')
                Operatingsystem    = $computer.operatingsystem
                IPv4Address        = $computer.ipv4address
                SamAccountName     = $Computer.SamAccountName
            }
            
            $object = New-Object psobject -Property $Properties
            $OldMachine.Add($object)
            
        } # foreach
        
        if ($OldMachine.count -gt 0) {
            
            if ($PSBoundParameters.ContainsKey('FilePath') ) {
                
                try {
                    
                    Write-Verbose "[PROCESS] Generating CSV File"
                    $OldMachine | export-csv -NoTypeInformation -Path $FilePath -Encoding Unicode
                    Write-Verbose "[PROCESS] File generate: $FilePath"
                }
                catch {
                    
                    Write-Warning "Couldn't export to file"
                    
                } # try catch
            }
            else {
                Write-Output $OldMachine
            }
        } # oldmachine if
           
    } # try 
    catch {
        Write-Error $_

    } # catch
        
} # process

end {

    Write-Verbose "[END    ] Ending $($MyInvocation.MyCommand)"

} # end