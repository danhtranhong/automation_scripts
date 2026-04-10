
#$Groups = Get-Content "\\vdi-profiles\home\admin-hdt\Desktop\psc-groups.txt"

# foreach ($Group in $Groups) {
#     Get-ADGroupMember -Identity $Group -Recursive |
#     Where-Object {$_.ObjectClass -eq "user"} |
#     Select-Object @{Name="Group";Expression={$Group}},
#                   Name, SamAccountName
# }

$Groups = Get-Content "\\vdi-profiles\home\admin-hdt\Desktop\psc-groups.txt"
$Results = @()

foreach ($Group in $Groups) {
    $Members = Get-ADGroupMember -Identity $Group -Recursive -ErrorAction Stop |
               Where-Object {$_.ObjectClass -eq "user"} |
               Get-ADUser -Properties EmailAddress, Department

    foreach ($User in $Members) {
        $Results += [PSCustomObject]@{
            Group          = $Group
            Name           = $User.Name
            SamAccountName = $User.SamAccountName
            Email          = $User.EmailAddress
            Department     = $User.Department
        }
    }
}

$Results | Export-Csv "\\vdi-profiles\home\admin-hdt\Desktop\GroupMembers.csv" -NoTypeInformation
