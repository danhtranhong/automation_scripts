#$GroupListFile = "\\vdi-profiles\home\admin-hdt\Desktop\list.txt"
$GroupListFile = "\\vdi-profiles\home\admin-hdt\Desktop\delete_list.txt"


if (-not (Test-Path $GroupListFile)) {
    Write-Error "File not found: $GroupListFile"
    exit
}

$names   = Get-Content $GroupListFile | Where-Object { $_.Trim() -ne "" }
$Results = @()

foreach ($GroupName in $names) {
    try {
        $group = Get-ADGroup -Identity $GroupName -Properties ManagedBy -ErrorAction Stop

        if ($group.ManagedBy) {
            # Works for users AND groups
            $owner = Get-ADObject -Identity $group.ManagedBy -Properties displayName, mail, samAccountName

            $Results += [PSCustomObject]@{
                GroupName      = $group.Name
                OwnerName      = $owner.displayName
                #OwnerUsername  = $owner.samAccountName
                OwnerEmail     = $owner.mail
            }
        }
        else {
            $Results += [PSCustomObject]@{
                GroupName      = $group.Name
                OwnerName      = "<No owner assigned>"
                #OwnerUsername  = ""
                OwnerEmail     = ""
            }
        }
    }
    catch {
        $Results += [PSCustomObject]@{
            GroupName      = $GroupName
            OwnerName      = "<Group not found or error>"
            #OwnerUsername  = ""
            OwnerEmail     = ""
        }
    }
}

# Output
$Results | Format-Table -AutoSize