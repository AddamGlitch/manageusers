[xml]$usersXml = Get-Content -Path "\assignments\users.xml"

# Create the root OU
New-ADOrganizationalUnit -Name "comedians" -Path "DC=esage,DC=us"

# Loop through each user in the XML and create the corresponding AD object
foreach ($user in $usersXml.root.user) {
    $userProps = @{
        Name = $user.account
        GivenName = $user.firstname
        Surname = $user.lastname
        Description = $user.description
        AccountPassword = (ConvertTo-SecureString $user.password -AsPlainText -Force)
        Enabled = $true
        Path = "OU=comedians,DC=esage,DC=us"
    }

    # Check if the user has a manager and set the manager property accordingly
    if ([string]::IsNullOrWhiteSpace($user.manager)) {
        $userProps.Manager = $null
    } else {
        $userProps.Manager = "CN=$($user.manager),OU=comedians,DC=esage,DC=us"
    }

    New-ADUser @userProps

    # Loop through each group the user is a member of and add them to the corresponding AD group
    foreach ($group in $user.memberOf.group) {
        Add-ADGroupMember -Identity $group -Members $user.account
    }
}




HOGJAHGMQAIGHAJIRHNAGOIJORHGA0


jah i ghaiguaGNOIUngwawsgvsaav