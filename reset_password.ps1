
Import-Module ActiveDirectory



$DefaultPassword = ConvertTo-SecureString "Password" -AsPlainText -Force

$UserList = @("user1","user2","user3")

#$UserList = Import-Csv "C:\Temp\users.csv"


foreach ($User in $UserList) {
    Set-ADAccountPassword -Identity $User -Reset -NewPassword $DefaultPassword
    Set-ADUser -Identity $User -ChangePasswordAtLogon $true
    Write-Host "Password reset for $User"
}
