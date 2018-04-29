function Get-InactiveComputer {
    [CmdletBinding()]
    param (

        [Alias('cn', 'Server', 'DomainController')]
        [String]
        $ComputerName,

        $Credential,

        [String]
        $SearchBase,
    
        [Int]
        $InactiveDay = 30, 

        [String]
        $FilePath,

        [Switch]
        $Disable,

        [String]
        $DestinationOU

    ) # param

    begin {
        Import-Module ActiveDirectory -Verbose:$false
        Write-Verbose "[BEGIN  ] Starting $($MyInvocation.MyCommand)"

    } # begin

    process {

        $time = (Get-Date).AddDays( - ($InactiveDay))

    
        # Create Array
        $OldMachine = New-Object System.Collections.Generic.List[System.Object]
    
        $Arguments = @{
            ErrorAction = 'Stop'
            Filter      = {LastLogonTimeStamp -lt $Time }
            Properties  = 'LastLogonTimeStamp', 'enabled', 'pwdLastSet'
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

    
        # Retrieve computers comparing last logon and last password change
        try {

            Write-Verbose "[PROCESS] Retrieving computers"
            $LastLogon = Get-ADComputer @Arguments 
        
       
            # Double checking inactive computers
            foreach ($computer in $LastLogon) {
            

                $Properties = @{
                    Name            = $computer.Name
                    Enabled         = $Computer.Enabled
                    LastDomainLogon = [DateTime]::FromFileTime($computer.lastLogonTimestamp).ToString('yyyy-MM-dd')
                }
                
                $object = New-Object psobject -Property $Properties
                $OldMachine.Add($object)
          
            } # foreach
            try {

                if ($OldMachine.count -gt 0) {

                    if (-not($disable)) {
                        Write-Output $OldMachine

                    }
                
                    if ($PSBoundParameters.ContainsKey('FilePath') ) {
                    
                        try {
                        
                            $OldMachine | export-csv -NoTypeInformation -Path $FilePath -Encoding Unicode
                        }
                        catch {
                        
                            Write-Warning "Couldn't export to file"
                        
                        } # try catch
                    
                    } # if FilePath 

                    if ($disable) {

                        Foreach ($object in $OldMachine) {
                            try {

                                Write-Verbose "[PROCESS] Disabling $($Object.Name)"
                                Get-ADComputer -Identity $Object.Name | Disable-ADAccount -ErrorAction Stop
                                $object.enabled = $False
                            
                            }
                            catch {

                                Write-Warning "Couldn't disable $($Object.Name)"
                            
                            } # try catch disable
                        } # foreach
                        Write-Output $OldMachine
                    
                    } # if disable
                
                
                    if ($DestinationOU) {
                        Foreach ($object in $OldMachine) {
                            try {
    
                                Write-Verbose "[PROCESS] Moving $($Object.Name) to $DestinationOU"
                                Get-ADComputer -Identity $object.Name | Move-ADobject -TargetPath $DestinationOU -ErrorAction Stop
                            
                            }
                            catch {
    
                                Write-Warning "Couldn't move $($Object.Name) to $DestinationOU."
                            
                            } # try catch disable
                        } # foreach

                    } # if destinationOU

                } # oldmachine if
            }
            catch {

            } # try catch disable
            
        } # try 
        catch {
            Write-Error $_

        } # catch
        
    } # process

    end {

        Write-Verbose "[END    ] Ending $($MyInvocation.MyCommand)"

    } # end

} # function