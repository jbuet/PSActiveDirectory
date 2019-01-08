<#
    .SYNOPSIS
    Set-UserLogonHours - Modify logon hours of user

    .DESCRIPTION
    It allows to modify the logon hours of an user. 
    You can enable or disable the login of an user without disabling the account or resetting the password.
    This cmdlet only changes the value of the attribute LogonHours 

    .PARAMETER Identity
    SamAccountName of the user.

    .PARAMETER Status
    Status to set to the user:
    Allow: enable user to login at any hour.
    Denied: deny user to login to Active Directory.

    .EXAMPLE
    Set-UserLogonHours -Identity jbuet -Status Allow -Verbose
    Allows user "jbuet" to authenticate to Active Directory.

    .EXAMPLE
    Import-Csv -Path c:\users.csv | Set-UserLogonHours -Verbose -Status Denied
    Deny authentication to users imported on the CSV file "C:\users.csv"
   
    .LINK
        https://github.com/jbuet/PSActiveDirectory
    
   
    .NOTES
    Requiriments:
        * ActiveDirectory Module
        * AD Permissions to modify an user
    
    Version 0.1.0 04/08/2017: Creation of cmdlet
    Version 0.1.1 05/01/2019: Fix help docs


#>

#Requires -Module ActiveDirectory

[CmdletBinding()]
param (

    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [String[]]
    $Identity,

    [Parameter(Mandatory, ValueFromPipelineByPropertyName, HelpMessage = "Status of login: Allow or Denied")]
    [ValidateSet("Allow", "Denied")]
    $Status

)

begin {

    Write-Verbose "[BEGIN  ] Starting $($MyInvocation.MyCommand)"

    # For Powershell V2
    Import-Module ActiveDirectory -Verbose:$False

    # Denies all hours all days
    [byte[]]$hours = @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

} # begin

process {
    foreach ($user in $Identity) {
        Write-Verbose "[PROCESS] Setting user: $User"
        
        Switch ($Status) {
            'Allow' {
                Write-Verbose "[PROCESS] Allowing login to user: $User"
                $parameter = @{ Clear = 'LogonHours' }
            } # end allow

            'Denied' {
                Write-Verbose "[PROCESS] Denying login to user: $User"
                $parameter = @{ 
                    Replace = @{ logonhours = $hours } 
                }
            } # end denied

        } # end switch

        # Modifies User
        Try {
            Set-ADUser -Identity $User @Parameter
        }
        catch {
            Write-Error $_
        }
        
    } # foreach
} # process

end {

    Write-Verbose "[END   ] Ending $($MyInvocation.MyCommand)"

} # end
