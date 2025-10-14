#THIS SCRIPT ELEVATES THE STARTED PS SESSION TO ADMIN
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}

#SETTING THE CONSOLE COLOR TO BLACK, STARTING THE TRANSCRIPT
CMD /C Color 0F
$DesktopPath = [Environment]::GetFolderPath("Desktop")
Start-Transcript -path $DesktopPath\AADGUIDStamper.txt -append

#IMPORTING AD MODULE
Import-Module ActiveDirectory

#ARE WE INSTALLING MGGRAPH?
$MgGraphInstallMessage = @"
*********************************************
* Do you wish to install Microsoft MgGraph? *
*             [1 = yes, 0 = no]             *
*********************************************
"@
Write-Host $MgGraphInstallMessage -ForegroundColor Cyan
$MgGraphInstallPrompt = Read-Host
Write-Output "You've entered: $MgGraphInstallPrompt"

if ($MgGraphInstallPrompt -eq 1) {
    Write-Output "Installing Microsoft MgGraph..."
    Install-Module Microsoft.Graph -Scope AllUsers -Force
} elseif ($MgGraphInstallPrompt -eq 0) {
    #SKIPPING
} else {
    Read-Host -Prompt "Answer not found. Press Enter to exit"
    Exit
}

#SWITCH-CASE SCENARIO
$switchcasemessage = @"
**************************************************************************
* 1. If this is your first time running this script, input 1 and the     *
* script will create a directory and parse all Active Directory active   *
* users' UserPrincipalNames into that CSV file.                          *
*                                                                        *
*                                 |||                                    *
*                                                                        *
* 2. If you already have an adsanupn.csv updated and ready in C:\by3142  *
* input 2 and the program will start the corresponding attribute         *
* update process.                                                        *
*                                                                        *
*                                 |||                                    *
*                                                                        *
* 3. If your file is ready, but is elsewhere or has a different name,    * 
* input 3 to declare the filepath.                                       *
*                                                                        *
*                                 |||                                    *
*                          [ADDITIONAL INFO]                             *
* The CSV file includes multiple columns, but we need only three:        *
* The SamAccountName, the UserPrincipalName and the Name.                *
* SamAccountName is needed to get the UUID/GUID/UserImmutableID that can *
* be acquired also from Portal.Azure.com > Microsoft Entra ID > Microsoft*
* Entra Connect > Connect Sync > Microsoft Connect Entra Health > Sync   *
* Errors. On this step, we are specifically targetting the UUID of the   *
* On-Premise AD user (can seen on Source Anchor row).                    *
*                                                                        *
* Afterwards, we'll need "hardstamp" it on the Azure AD user via         *
* >>Update-MgUser -UserId [UPN] -OnPremisesImmutableId [UUID] command    *
* Therefore, for the script to function properly, you will need PS Admin *
* session on On-Premises AD and a Global Administrator account on Azure. *
*                                                                        *
* The column names are declared and called AS IS in the CSV file.        *
* Therefore, the script is designed with RUN AS IS in mind and should    *
* function properly with no additional edits.                            *
*                                                                        *
* IMPORTANT: The code will be applied EXCLUSIVELY to users who's UPN     *
* contains the domain that will be prompted further.                     *
* Therefore, if you enter sakurada.lan as your domain, the update-mguser *
* will be ran ONLY on *@sakurada.lan users.                              *
**************************************************************************
Input: 
"@

Write-Host $switchcasemessage -ForegroundColor Cyan
$fileswitchcase = Read-Host
Write-Output "You've entered: $fileswitchcase"

if ($fileswitchcase -eq 1) {
    New-Item -Path "c:\" -Name "by3142" -ItemType "directory"
    Get-ADUser -Filter * -Properties UserPrincipalName | Where { $_.Enabled -eq $True} | export-csv C:\by3142\adsanupn.csv
    Read-Host -Prompt "CHECK C:\BY3142 FOR THE ADSANUPN CSV FILE. EDIT AS NECESSARY 1/2"
    Read-Host -Prompt "CHECK C:\BY3142 FOR THE ADSANUPN CSV FILE. EDIT AS NECESSARY 2/2"
    $filepath = "C:\by3142\adsanupn.csv"
    Write-Output "Filepath = $filepath"
} elseif ($fileswitchcase -eq 2) {
    $filepath = "C:\by3142\adsanupn.csv"
    Write-Output "Filepath set to: $filepath"
} elseif ($fileswitchcase -eq 3) {
    Write-Output "Please enter the absolute file path below: "
    $filepath = Read-Host
    Write-Output "Filepath set to: $filepath"
} else {
    Read-Host -Prompt "Answer not found. Press Enter to exit"
    Exit
}

#DOMAIN VARIABLE
$domainvariable = @"
***************************************
* Enter the domain for which you need *
* to update the UUIDs                 *
* Example: contoso.com                *    
***************************************
*DOMAIN:
"@
Write-Host $domainvariable -ForegroundColor Cyan
$domainvariable = Read-Host

#CONNECTING TO AZURE AD THROUGH MGGRAPH
Write-Output "Connecting to Azure AD through MgGraph... (Scopes: User.ReadWrite.All, Directory.AccessAsUser.All)"
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.AccessAsUser.All"

#YESNO-SAFEHOUSE
$safehousemessage = @"
****************************************************
* Upon continuation, the script will run a         *
* Update-MgUser cycle for the entire AAD. It is    *
* highly advised that you understand what you're   *
* doing and make sure everything, both in code and *
* in the CSV file is correct.                      *
*                                                  *
*       Do you wish to continue? [yes/no]          *
****************************************************
"@
Write-Host $safehousemessage -ForegroundColor Yellow
$safehouse = read-host
Write-Output "You've entered: $safehouse"

#DECLARING THE VARIABLES FOR ERROR MESSAGES, IMPORTING THE CSV FILE AND STARTING THE UUID HARDSTAMP CYCLE
$adsanupn = Import-Csv -Path $filepath
$okmessage = "OK!"
$user404Errormessage = @"
**********************************
*        USER NOT FOUND!         *
**********************************
*USER: 
"@
$adusernotfoundlist = @"
***************************************
*        USERS NOT FOUND (AD):        *
***************************************
*LIST:

"@
$aadusernotfoundlist = @"
***************************************
*        USERS NOT FOUND (AAD):       *
***************************************
*LIST:

"@
$otherdomainuserlist = @"
*************************************************
*        USERS ARE IN OTHER DOMAIN (AD):        *
*************************************************
*LIST:

"@
Write-Output "======================="
Write-Output " "

if ($safehouse -eq "yes") { 
    $adsanupn | ForEach-Object {
        if ($_.UserPrincipalName -like "*$domainvariable") {
            $error.clear()
            Try {
                $varsamaccname = Get-ADUser $_.SamAccountName
            } catch {
                #Catch function doesn't inherit from global environment so we gotta do an extra ifelse below
            }
            
            if ($error) {
                Write-Output " "
                Write-Host $user404Errormessage $_.SamAccountName -ForegroundColor Red
                Write-Output "======================="
                $adusernotfoundlist = $adusernotfoundlist + " $_.SamAccountName `n"
            } elseif (!$error) {
                $User = Get-ADUser -Identity $_.SamAccountName -Properties ObjectGUID
                $GuidObject = [GUID]$User.'ObjectGUID'
                $GuidString = $GuidObject.Guid
                $Base64 = [Convert]::ToBase64String(([Guid]$GuidString).ToByteArray())

                $Name = $_.Name
                $SamAccName = $_.SamAccountName
                $UPN = $_.UserPrincipalName

                Write-Host "User:           $Name" -ForegroundColor Blue
                Write-Host "SamAccountName: $SamAccName" -ForegroundColor Cyan
                Write-Host "GUID string:    $GuidString" -ForegroundColor Magenta
                Write-Host "Base64 convert: $Base64" -ForegroundColor DarkGreen
                
                $error.clear()
                Try {
                    $varupn = Get-MgUser -UserId $_.UserPrincipalName
                } catch {
                    #Catch function doesn't inherit from global environment so we gotta do an extra ifelse below
                }
                
                if ($error) {
                    $varupnError = $_.UserPrincipalName
                    Write-Output " "
                    Write-Host $user404Errormessage $varupnError -ForegroundColor Red
                    Write-Output "======================="
                    $aadusernotfoundlist = $aadusernotfoundlist + " $varupnError `n"
                } elseif (!$error) {
                    Update-MgUser -UserId $_.UserPrincipalName -OnPremisesImmutableId $Base64
                    Write-Host "Hardstamping $Base64 to $UPN" -ForegroundColor Green
                }

                Write-Host $okmessage -ForegroundColor Green
                Write-Output "======================="
           }
        } elseif ($_.UserPrincipalName -notlike "*$domainvariable") {
            $UPN = $_.UserPrincipalName
            $otherdomainuserlist = $otherdomainuserlist + " $UPN `n"
        }
    }
} else {
    Write-Output "Huh?"
} 

Write-Host $adusernotfoundlist -ForegroundColor Red
Write-Host $aadusernotfoundlist -ForegroundColor Red
Write-Host $otherdomainuserlist -ForegroundColor Red

#STOPPING THE TRANSCRIPT
Write-Host " "
Stop-Transcript

Read-Host -Prompt "
___.           ________  ____   _____ ________  
\_ |__ ___.__. \_____  \/_   | /  |  |\_____  \ 
 | __ <   |  |   _(__  < |   |/   |  |_/  ____/ 
 | \_\ \___  |  /       \|   /    ^   /       \ 
 |___  / ____| /______  /|___\____   |\_______ \
     \/\/             \/          |__|        \/
       END OF SCRIPT. PRESS ENTER TO EXIT.       
   THE TRANSCRIPT CAN BE FOUND ON THE DESKTOP.  
                        "
