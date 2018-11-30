#
# 
#

#Load Assembly and Library
Add-Type -AssemblyName PresentationFramework
Add-Type -Assembly System.Drawing

#
# Functions
#
function AdminCheck{
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] “Administrator”))
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!","Error",0,[System.Windows.Forms.MessageBoxIcon]::Error)
        Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
        Break
    }
}

function GUI($applications, $praefix){
    #Write-Host $applications
    
    # Build the GUI
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="App Installer" Height="300" Width="400"
        WindowStartupLocation="CenterScreen"
        WindowStyle="SingleBorderWindow" ResizeMode="CanMinimize">
    <Grid>
        <ListBox Name="ListBox" HorizontalAlignment="Stretch" Margin="10,10,10,35" VerticalAlignment="Stretch"/>
        <Button Name="Select" Content="Select" HorizontalAlignment="Left" Margin="10,0,0,10" VerticalAlignment="Bottom" Width="75"/>
    </Grid>
</Window>
"@
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
    $XMLForm=[Windows.Markup.XamlReader]::Load( $reader )
    if($praefix -eq $null){
        $XMLForm.Title = "App Installer"
    }else{
        $XMLForm.Title = $praefix
    }
    function Exe2Png($exe){
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exe)
        $bmp = $icon.ToBitmap()
        $stream = new-object System.IO.MemoryStream
        $bmp.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $imageSource = [System.Windows.Media.Imaging.BitmapFrame]::Create($stream); 
        return $imageSource
    }
    $XMLForm.Icon = Exe2Png "C:\Windows\System32\mmc.exe"      
    
    # Create items for listbox
    $ListBox = $XMLForm.FindName('ListBox')    
    if($praefix -ne $null){      
        $names = $applications.$($praefix).psobject.properties.name | Sort-Object
        if($names.Count -eq 1){
            $global:guiselection += $names
            return $null
        }else{
            foreach($a in $names){        
                $ListBox.Items.Add($a) | Out-Null
            }
        }
    }else{
        $names = $applications.psobject.properties.name | Sort-Object
        foreach($a in $names){        
            $ListBox.Items.Add($a) | Out-Null
        }
    }
    
    # Save selected item    
    $SelectButton = $XMLForm.FindName("Select")
    $SelectButton.add_Click({
        foreach ($objItem in $ListBox.SelectedItems)
	    { $global:guiselection += $objItem}
	    $XMLForm.Close()
    })
    
    # Show form    
    $XMLForm.ShowDialog() | Out-Null
}

function InstallSoftware{
    Write-Host "Installing: $($global:guiselection)" -ForegroundColor Green
    [PSCustomObject]$jsonPath = $global:guiselection
    $obj =  $applications.$($jsonPath[0]).$($jsonPath[1])
   
    if($obj.Path -like "*.cmd"){
        if($obj.Arguments -ne $null -or $obj.Arguments -ne ""){
            Start-Process "cmd.exe" -ArgumentList "/c `"$($obj.Path)`" $($obj.Arguments)"
        }else{
            Start-Process "cmd.exe" -ArgumentList "/c `"$($obj.Path)`""
        }
    }    
    elseif($obj.Path -like "*.ps1"){
        if($obj.Arguments -ne $null -or $obj.Arguments -ne ""){
            start-process powershell -Argumentlist "-file `"$($obj.Path)`" $($obj.Arguments)"
        }else{
            start-process powershell -Argumentlist "-file `"$($obj.Path)`""
        }
    }elseif($obj.Path -like "*.exe"){
        if($obj.Arguments -ne $null -and $obj.Arguments -ne ""){
            Start-Process $obj.Path -ArgumentList $obj.Arguments
        }else{
            Start-Process $obj.Path
        }
    }else{
        exit
    }
}

#
# Main
#
Write-host "#######################"
Write-host "#    App Installer    #"
Write-host "#    Version 1.0      #"
Write-host "#######################"

# Admin check
AdminCheck

# Program data
$applications = Get-Content "$($PSScriptRoot)\AppInstaller.json" | ConvertFrom-Json   

# User selection
$global:guiselection = @()
GUI $applications
foreach($selected in $global:guiselection){
GUI $applications $selected
}
InstallSoftware
pause
