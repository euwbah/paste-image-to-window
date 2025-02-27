# filepath: /c:/Users/dacoo/CLionProjects/paste-image-to-window/uninstall.ps1
# Check if the script is running as an administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "Need administrator to remove background startup task. Restarting script with elevated privileges..."
    # Attempt to restart the script with elevated privileges
    $newProcess = Start-Process powershell -ArgumentList " -File `"$PSCommandPath`"" -Verb RunAs -PassThru -WorkingDirectory $PSScriptRoot
    $newProcess.WaitForExit()
    exit
}

Set-Location -Path $PSScriptRoot

# echo current working directory
Write-Output "Current working directory: $PSScriptRoot"

# Define the task name
$taskName = "Paste Image To Window"

# Check if the scheduled task exists and remove it if it does
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Output "Scheduled task '$taskName' has been removed."
} else {
    Write-Output "Scheduled task '$taskName' does not exist."
}

# Remove the launcher script if it exists
$runScriptPath = "$PSScriptRoot\paste-image-to-window-launcher.ps1"
if (Test-Path $runScriptPath) {
    Remove-Item $runScriptPath -Force
    Write-Output "Launcher script '$runScriptPath' has been removed."
} else {
    Write-Output "Launcher script '$runScriptPath' does not exist."
}

# Terminate the paste-image-to-window.exe process if it is running
$processName = "paste-image-to-window"
$process = Get-Process -Name $processName -ErrorAction SilentlyContinue
if ($process) {
    Stop-Process -Name $processName -Force
    Write-Output "Process '$processName.exe' has been terminated."
} else {
    Write-Output "Process '$processName.exe' is not running."
}

Write-Output "Uninstallation complete. You may now delete this folder."
Write-Output "Press any key to continue..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
