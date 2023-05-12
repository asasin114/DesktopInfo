$PackageName = "DesktopInfo"
$Description = "Application to show computer name and relevant support info on Desktop."

$url = "https://github.com/asasin114/DesktopInfo/raw/main/"
$output = "C:\Program Files\4net\EndpointManager\Program\DesktopInfo"
$Path_4netIntune = "$Env:Programfiles\4net\EndpointManager"
Start-Transcript -Path "$Path_4netIntune\Log\$PackageName-install.log" -Force

###########################################################################################
# Kill existing task
###########################################################################################

taskkill /IM DesktopInfo64.exe /F

###########################################################################################
# Initial Setup and Variables
###########################################################################################

New-item -itemtype directory -force -path "$Path_4netIntune\Program\DesktopInfo"
Invoke-WebRequest -Uri "$url/DesktopInfo64.exe" -OutFile "$output\DesktopInfo64.exe"
Invoke-WebRequest -Uri "$url/hostname.ini" -OutFile "$output\hostname.ini"
Invoke-WebRequest -Uri "$url/DesktopInfo.ps1" -OutFile "$output\DesktopInfo.ps1"

###########################################################################################
# Create dummy vbscript to hide PowerShell Window popping up at logon
###########################################################################################

$vbsDummyScript = "
Dim shell,fso,file

Set shell=CreateObject(`"WScript.Shell`")
Set fso=CreateObject(`"Scripting.FileSystemObject`")

strPath=WScript.Arguments.Item(0)

If fso.FileExists(strPath) Then
	set file=fso.GetFile(strPath)
	strCMD=`"powershell -nologo -executionpolicy ByPass -command `" & Chr(34) & `"&{`" &_
	file.ShortPath & `"}`" & Chr(34)
	shell.Run strCMD,0
End If
"

$scriptSavePathName = "$PackageName-VBSHelper.vbs"

$dummyScriptPath = $(Join-Path -Path $scriptSavePath -ChildPath $scriptSavePathName)

$vbsDummyScript | Out-File -FilePath $dummyScriptPath -Force

$wscriptPath = Join-Path $env:SystemRoot -ChildPath "System32\wscript.exe"

###########################################################################################
# Register a scheduled task to run for all users and execute the script on logon
###########################################################################################

$schtaskName = $PackageName
$schtaskDescription = $Description

$trigger = New-ScheduledTaskTrigger -AtLogOn

###########################################################################################
#Execute task in users context
###########################################################################################

$principal= New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -Id "Author"

###########################################################################################
#call the vbscript helper and pass the PosH script as argument
###########################################################################################

$action = New-ScheduledTaskAction -Execute $wscriptPath -Argument "`"$dummyScriptPath`" `"$scriptPath`""

$settings= New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$null=Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger -Action $action -Principal $principal -Settings $settings -Description $schtaskDescription -Force

Start-ScheduledTask -TaskName $schtaskName

Stop-Transcript