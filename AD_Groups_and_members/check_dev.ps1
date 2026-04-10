
# ------------------------------------------
# NTFS Permissions Viewer (PowerShell + WPF)
# ------------------------------------------

# Ensure Single-Threaded Apartment (required for WPF)
if (![System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "Restarting PowerShell with -STA..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoLogo -STA -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Load required WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# -----------------------
# Function: Get NTFS ACLs
# -----------------------
function Get-NtfsPermissions {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [int]$Depth = 3
    )

    if (!(Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }

    $results = New-Object System.Collections.Generic.List[object]

    # Use -Recurse with -Depth (PowerShell 5.0+)
    Get-ChildItem -LiteralPath $Path -Directory -Recurse -Depth $Depth -ErrorAction SilentlyContinue |
    ForEach-Object {
        $folder = $_.FullName
        try {
            $acl = Get-Acl -LiteralPath $folder
        } catch {
            # Skip folders we can't read
            return
        }

        foreach ($rule in $acl.Access) {
            $results.Add([PSCustomObject]@{
                Directory      = $folder
                Account        = $rule.IdentityReference.Value
                Rights         = $rule.FileSystemRights.ToString()
                Type           = $rule.AccessControlType.ToString()
                AppliesTo      = $rule.InheritanceFlags.ToString()
                Inherited      = [bool]$rule.IsInherited
                Owner          = $acl.Owner
            })
        }
    }

    return $results
}

# -----------------------
# GUI XAML
# -----------------------
[xml]$xaml = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='NTFS Permission Viewer'
        Width='1300' Height='750' WindowStartupLocation='CenterScreen'>
    <Grid Margin='10'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>
            <RowDefinition Height='*'/>
            <RowDefinition Height='Auto'/>
        </Grid.RowDefinitions>

        <StackPanel Orientation='Horizontal' Grid.Row='0' Margin='0 0 0 10'>
            <Label Content='Path:'/>
            <TextBox x:Name='txtPath' Width='500' Margin='5,0'/>
            <Button x:Name='btnBrowse' Content='Browse' Width='80' Margin='5,0'/>
            <Label Content='Depth:' Margin='10,0,0,0'/>
            <TextBox x:Name='txtDepth' Width='50' Text='3' Margin='5,0'/>
            <Button x:Name='btnRun' Content='Run' Width='90' Margin='10,0'/>
            <Button x:Name='btnExport' Content='Export CSV' Width='120' Margin='10,0'/>
        </StackPanel>

        <DataGrid x:Name='dgResults'
                  Grid.Row='1'
                  AutoGenerateColumns='True'
                  IsReadOnly='True'
                  AlternatingRowBackground='LightGray'
                  EnableRowVirtualization='True'
                  VirtualizingPanel.IsVirtualizing='True'
                  VirtualizingPanel.VirtualizationMode='Standard'/>

        <TextBlock x:Name='lblStatus'
                   Grid.Row='2'
                   FontWeight='Bold'
                   Margin='5,10,0,0'/>
    </Grid>
</Window>
"@

# Load GUI safely
try {
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Failed to parse/load XAML: $($_.Exception.Message)"
    throw
} finally {
    if ($reader) { $reader.Close() }
}

# Resolve controls using FindName (reliable)
$txtPath   = $window.FindName('txtPath')
$btnBrowse = $window.FindName('btnBrowse')
$txtDepth  = $window.FindName('txtDepth')
$btnRun    = $window.FindName('btnRun')
$btnExport = $window.FindName('btnExport')
$dgResults = $window.FindName('dgResults')
$lblStatus = $window.FindName('lblStatus')

# Guard against nulls (helps diagnose)
$controls = @{
    txtPath   = $txtPath
    btnBrowse = $btnBrowse
    txtDepth  = $txtDepth
    btnRun    = $btnRun
    btnExport = $btnExport
    dgResults = $dgResults
    lblStatus = $lblStatus
}
$nullControls = $controls.GetEnumerator() | Where-Object { $_.Value -eq $null } | Select-Object -ExpandProperty Key
if ($nullControls) {
    throw "XAML control(s) not found: $($nullControls -join ', '). Check x:Name values and XAML."
}

# Folder Browser (using .NET dialog for simplicity)
Add-Type -AssemblyName System.Windows.Forms
$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Select a folder (UNC path supported if mapped or accessible)."
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtPath.Text = $fbd.SelectedPath
    }
})

# Run Scan
$btnRun.Add_Click({
    try {
        $lblStatus.Text = "Scanning..."
        $dgResults.ItemsSource = $null

        $path = $txtPath.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($path)) { throw "Please enter a path." }

        $depth = 3
        if (-not [int]::TryParse($txtDepth.Text, [ref]$depth)) {
            throw "Depth must be an integer."
        }

        $data = Get-NtfsPermissions -Path $path -Depth $depth
        $dgResults.ItemsSource = $data

        $lblStatus.Text = "Completed. $($data.Count) rows."
    }
    catch {
        $msg = $_.Exception.Message
        [System.Windows.MessageBox]::Show($msg, "Error", "OK", "Error")
        $lblStatus.Text = "Error: $msg"
    }
})

# Export CSV
$btnExport.Add_Click({
    try {
        if (-not $dgResults.ItemsSource) { throw "No data to export. Run a scan first." }
        $savePath = Join-Path $env:USERPROFILE "Desktop\NTFS_Permissions.csv"
        $dgResults.ItemsSource | Export-Csv -Path $savePath -NoTypeInformation -Encoding UTF8
        [System.Windows.MessageBox]::Show("Exported to: $savePath")
    }
    catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, "Export Error", "OK", "Error")
    }
})

# Show window
[void]$window.ShowDialog()
``
