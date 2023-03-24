# Load the XML file
$usersXml = [xml](Get-Content -Path "\assignments\users.xml")

$fileinput = Get-ChildItem -Path (read-host "Please enter file path")

# Loop through each unique OU in the XML and create the corresponding AD object
$ous = $usersXml.root.user | Select-Object -ExpandProperty ou -Unique
foreach ($ou in $ous) {
    $ouProps = @{
        Name = $ou
        Path = "DC=esage,DC=us"
    }
    New-ADOrganizationalUnit @ouProps
}

# Loop through each user in the XML and create the corresponding AD object
foreach ($user in $usersXml.root.user) {
    # Get the OU path for the user
    $ouPath = "OU=$($user.ou),DC=esage,DC=us"

    # Set the user properties
    $userProps = @{
        Name = $user.account
        GivenName = $user.firstname
        Surname = $user.lastname
        Description = $user.description
        AccountPassword = (ConvertTo-SecureString $user.password -AsPlainText -Force)
        Enabled = $true
        Path = $ouPath
    }

    # Check if the user has a manager and set the manager property accordingly
    if ([string]::IsNullOrWhiteSpace($user.manager)) {
        $userProps.Manager = $null
    } else {
        $userProps.Manager = "CN=$($user.manager),$ouPath"
    }

    New-ADUser @userProps

    # Loop through each group the user is a member of and add them to the corresponding AD group
    foreach ($group in $user.memberOf.group) {
        Add-ADGroupMember -Identity $group -Members $user.account
    }
}