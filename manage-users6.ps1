
# Load the XML file
$fileinput = Get-ChildItem -Path (read-host "Please enter file path")

$usersXml = [xml] (Get-Content -Path $fileinput)

# Loop through each unique OU in the XML and create the corresponding AD object
$ous = $usersXml.root.user | Select-Object -ExpandProperty ou -Unique
foreach ($ou in $ous) {
    # Check if the OU already exists
    if (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue) {
        Write-Warning "OU '$ou' already exists. Skipping creation."
        continue
    }

    $ouProperties = @{
        Name = $ou
        Path = "DC=esage,DC=us"
    }

    try {
        New-ADOrganizationalUnit @ouProperties -ErrorAction Stop
    } catch {
        Write-Error "Error creating OU '$ou': $($_.Exception.Message)"
        continue
    }
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

    # Check if the user already exists
    if (Get-ADUser -Filter "Name -eq '$($user.account)'" -ErrorAction SilentlyContinue) {
        Write-Warning "User '$($user.account)' already exists. Skipping creation."
        continue
    }

    # Check if the user's manager exists
    $manager = Get-ADUser -Filter "Name -eq '$($user.manager)'" -ErrorAction SilentlyContinue
    if ($user.manager -and !$manager) {
        Write-Warning "Manager '$($user.manager)' for user '$($user.account)' does not exist. Skipping setting Manager property."
        continue
    } elseif ($manager) {
        $userProps.Manager = $manager
    }

    try {
        New-ADUser @userProps -ErrorAction Stop
    } catch {
        Write-Error "Error creating user '$($user.account)': $($_.Exception.Message)"
        continue
    }

    # Loop through each group the user is a member of and add them to the corresponding AD group
    foreach ($group in $user.memberOf.group) {
        try {
            Add-ADGroupMember -Identity $group -Members $user.account -ErrorAction Stop
        } catch {
            Write-Error "Error adding user '$($user.account)' to group '$group': $($_.Exception.Message)"
        }
    }
}