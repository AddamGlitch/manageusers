# Load the XML file
$fileinput = Get-ChildItem -Path (Read-Host "Please enter file path")

$usersXml = [xml] (Get-Content -Path $fileinput)

# Loop through each unique OU in the XML and create the corresponding AD object
$ous = $usersXml.root.user | Select-Object -ExpandProperty ou -Unique
foreach ($ou in $ous) {
    # Check if the OU already exists
    if (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue) {
        Write-Host "OU '$ou' already exists. Skipping creation." -ForegroundColor Yellow
        continue
    }

    $ouProperties = @{
        Name = $ou
        Path = "DC=esage,DC=us"
    }

    try {
        New-ADOrganizationalUnit @ouProperties -ErrorAction Stop
        Write-Host "Created OU '$ou'." -ForegroundColor Green
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
        Write-Host "User '$($user.account)' already exists. Skipping creation." -ForegroundColor Yellow
        continue
    }

    try {
        # Check if the user's manager exists
        if (![string]::IsNullOrWhiteSpace($user.manager)) {
            $manager = Get-ADUser -Filter "Name -eq '$($user.manager)'" -ErrorAction Stop
            $userProps.Manager = "CN=$($manager.Name),$ouPath"
        }

        New-ADUser @userProps -ErrorAction Stop
        Write-Host "Created user '$($user.account)'." -ForegroundColor Green
    } catch {
        Write-Error "Error creating user '$($user.account)': $($_.Exception.Message)"
        continue
    }

    # Loop through each group the user is a member of and add them to the corresponding AD group
    foreach ($group in $user.memberOf.group) {
        try {
            Add-ADGroupMember -Identity $group -Members $user.account -ErrorAction Stop
            Write-Host "Added user '$($user.account)' to group '$group'." -ForegroundColor Green
        } catch {
            Write-Error "Error adding user '$($user.account)' to group '$group': $($_.Exception.Message)"
        }
    }
}