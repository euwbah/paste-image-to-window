# Check if the script is running as an administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "Need administrator to add background startup task. Restarting script with elevated privileges..."
    # Attempt to restart the script with elevated privileges
    $newProcess = Start-Process powershell -ArgumentList " -File `"$PSCommandPath`"" -Verb RunAs -PassThru -WorkingDirectory $PSScriptRoot
    $newProcess.WaitForExit()
    exit
}

Set-Location -Path $PSScriptRoot

# echo current working directory
Write-Output "Current working directory: $PSScriptRoot"

# Check if Rust is installed
if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    $rustInstallPrompt = Read-Host "Rust compiler is not installed. Do you want to install rustup and Rust? (Y/N)"
    if ($rustInstallPrompt -ne 'Y' -and $rustInstallPrompt -ne 'y') {
        Write-Output "Rust installation aborted. Exiting script."
        exit
    }
    Write-Output "Installing rustup and Rust..."

    # Download and install rustup
    Invoke-WebRequest -Uri https://sh.rustup.rs -OutFile rustup-init.exe
    Start-Process -FilePath ./rustup-init.exe -ArgumentList "-y" -NoNewWindow -Wait
    Remove-Item ./rustup-init.exe

    # Add Rust to the current session's PATH
    $env:PATH += ";$HOME\.cargo\bin"
}

# Before compiling, check if the app is currently running. If so, close it.

$processName = "paste-image-to-window"
$process = Get-Process -Name $processName -ErrorAction SilentlyContinue
if ($process) {
    Stop-Process -Name $processName -Force
    Write-Output "Detected '$processName.exe' running. Terminating process..."
}

# Compile the Rust project
Write-Output "Compiling..."
Start-Process -FilePath cargo -ArgumentList "build --release" -NoNewWindow -Wait

# Create a script to run the executable in the background
$exePath = "$PSScriptRoot\target\release\paste-image-to-window.exe"
$runScriptPath = "$PSScriptRoot\paste-image-to-window-launcher.ps1"
$runScriptContent = @"
# DO NOT DELETE OR MOVE THIS FILE/FOLDER. THE BACKGROUND TASK RUNS THIS SCRIPT AT THIS EXACT DIRECTORY.
Start-Process -FilePath "$exePath" -WindowStyle Hidden
"@
Set-Content -Path $runScriptPath -Value $runScriptContent

# Create a scheduled task to run the script at startup
$taskName = "Paste Image To Window"
$taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$runScriptPath`""
$taskTrigger = New-ScheduledTaskTrigger -AtLogOn
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# Check if a task with the same name exists and remove it if it does
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Register the new scheduled task
Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings

# Start the scheduled task
Start-ScheduledTask -TaskName $taskName

Write-Output "Installation complete."
Write-Output "Paste Image To Window currently running, and will automatically run in the background at startup."
Write-Output ""
Write-Output "IMPORTANT: Do not delete or move this folder. If you need to move this folder, reinstall after moving."
Write-Output ""
Write-Output "Press any key to continue..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
