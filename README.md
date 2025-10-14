**As any other Powershell file, you might need to unlock this one before opening through RMB > Properties > Unlock.**

Now, let's briefly go through what this script does and when you might need it.
Basically, both on Azure AD and in On-Premises AD, every user has a fingerprint in the form of a GUID - Globally Unique Identifier, and it is crucial during synchronization.

Upon syncing AD with AAD, it is the GUID that is compared and has to match. When the GUIDs match, there are no problems at all and the sync goes through flawlessly. However, when there's a GUID mismatch, 
the sync entirely falls apart, dragging the organizational structures and password writebacks along the way (possibly creating duplicates on AAD, too). And it makes sense: because of GUID mismatch,
you basically have two different users in different instances (AD and AAD) that only happened to have the same SamAccountName and UserPrincipalName. 

_These issues can be traced both on AAD side (Portal.Azure.com > Microsoft Entra ID > Microsoft Entra Connect > Connect Sync > Microsoft Connect Entra Health > Sync Errors) or on AD (Synchronization Service > Operations)._

Once you come to know the exact issue behind such behavior, the resolution seems easy: simply >>Update-MgUser -UserId [UPN] -OnPremisesImmutableId [UUID] and force the AD user's GUID onto AAD user. But what if you have not 5,
not 10, but 300 such users? It's precisely here when we need the AADGUID_Hardstamper. 

The script is fairly easy and only needs a simple CSV file with three columns: Name (full name of the user), SamAccountName (the username itself without the domain) and UserPrincipalName (full domain qualified username).
There's no need to prepare this file: the script will parse active users from the AD upon running it on a Windows Server with Active Directory services available and save it on C:\by3142\adsanupn.csv file.

**The function is simple:** the for-cycle takes the SamAccountName, parses the GUID from AD, converts it into Base64 string and pushes to AAD. If there are any users that didn't make it, you will see a corresponding error along
the way and a list at the very end of the script. The transcript of the whole process can be also found on the desktop upon finish.

That's pretty much it. Hope this saves you some time.
