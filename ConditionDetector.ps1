$ErrorActionPreference= 'silentlycontinue'
# Start-Transcript -Path "C:\Windows\BCD\BCDMon\Logs\$env:COMPUTERNAME-MonitorDEV.log" -Append

#Preload Variables
$ParseRegexe = '(?<=(Apparatus|BCDStatus) \s*=\s*)[^ ]+'
$registryKeyPath = "HKLM:\SOFTWARE\BCD\foundation"
$iniFilePath = "C:\BCD\Utilities\fixture.ini"

try {
    $bcdNam = Get-Content $iniFilePath | Where-Object { $_ -like "bcdNam:*" } | ForEach-Object { $_ -replace "bcdNam:\s*" }
    if ([string]::IsNullOrWhiteSpace($bcdNam)) {
        throw "BCD Name not found in fixture.ini"
    }
} catch {
    Write-Host "Failed to read BCD Name from fixture.ini: $_"
    $bcdNam = "Unable to ID"
}


#Generate UID
function New-UniqueId {
    $hostname = [System.Net.Dns]::GetHostName()
    $timestamp = (Get-Date).ToString('yyyyMMddHHmmssffff')
    return "$hostname-$timestamp"
}


#Set Variable for current date and time
$TimeStamp= (Get-Date).ToString('MM/dd/yyyy h:mm:ss tt')
$TimeZone = [System.TimeZoneInfo]::Local.Id
$TimeZoneEST = [System.TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')
$TimeStampEST = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), $TimeZoneEST.Id, 'Eastern Standard Time').ToString('MM/dd/yyyy h:mm:ss tt') + " EST"


#Create Qmon folder
$BCDFolder = "C:\Windows\BCD\BCDMon\Logs\Temp\BCD Manager\"
if (Test-Path $BCDFolder) {

Write-Host "Folder Exists"
# Perform Delete file from folder operation
}
else
{

#Create directory if not exists
New-Item $BCDFolder -ItemType Directory
Write-Host "Folder Created successfully"
}

# Agent Status Save Last Success as variable
$LastSuccess = Get-ItemProperty -Path HKLM:\SOFTWARE\BCD\Service | 
Select-Object -ExpandProperty LastAttainmentStatus 

# Pass variable to check if within 20 minutes 
$global:EmissaryStatus = if ($LastSuccess -ge ((Get-Date).AddMinutes(-20))){
	'1'
    #On-Line
	} else {
	'0'
    #Off-Line
	}

#Check if folder BFile Folder exist
$BFileFolder = "C:\Windows\BCD\BCDMon\Logs\Temp\BCD Manager\"
    
if (Test-Path $BFileFolder) {
Write-Host "Folder Exists"
# Perform Delete file from folder operation
}
else
{
#Check/Create BFile Folder
New-Item $BFileFolder -ItemType Directory
Write-Host "Folder Created successfully"
}

# Copy Log file, as it errors out if you try to read directly due to active writing
Copy-Item -Path "C:\ProgramData\NCR\APTRA\Logs\BCD Manager\BFile.log" -Destination "C:\Windows\BCD\BCDMon\Logs\Temp\BCD Manager\" -PassThru

$logFile = "C:\Windows\BCD\BCDMon\Logs\Temp\BCD Manager\BFile.log"
$outputFile = "C:\Windows\BCD\BCDMon\Logs\Temp\BCD Manager\BFile-filtered.csv"
$filteredOutputFile = "C:\Windows\BCD\BCDMon\Logs\Temp\BCD Manager\BFile-filtered-last10.csv"

# Filter and create the CSV
Get-Content $logFile |
ForEach-Object {
    if ($_ -match 'BFile: \[([\d\s]+)\]') {
        $matches[1] -replace '\s+', ','
    }
} |
Set-Content $outputFile

# Keep the last 10 entries and remove duplicates
$entries = Get-Content $outputFile |
Select-Object -Last 10 |
ForEach-Object {
    if ($_ -match '^\d$') {
        "0$_"
    } else {
        $_
    }
} |
Sort-Object -Unique -Descending

if ($entries.Count -gt 0) {
    $largestEntry = $entries[0]
    Set-Content $filteredOutputFile -Value $largestEntry
} else {
    Write-Warning "No BFile found."
}

$BCDCopy= (Get-Content "$filteredOutputFile")
Write-Host "BCDCopy: $BCDCopy"

#Check for service status
$global:UnitStatus= switch ($BCDCopy) {
"04" {"04"; break}
"03" {"03"; break}
"02" {"02"; break}
"01" {"01"; break}
"00" {"00"; break}
}
Write-Host "UnitStatus: $UnitStatus"

# Gather Faults from event viewer 
Start-Transcript -Path C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrors.TXT -Append -Force -ErrorAction SilentlyContinue
Get-WinEvent -FilterHashTable @{LogName='Application';ID='16';StartTime=(Get-Date).AddMinutes(-5)} | Select-Object -ExpandProperty message
Stop-Transcript 

<# Gather Faults from event viewer - DEV TEST
Start-Transcript -Path C:\Windows\QLAbs\QMon\Logs\Temp\StatusErrors.TXT -Append -Force -ErrorAction SilentlyContinue
Get-WinEvent -FilterHashTable @{LogName='Application';ID='16'} -MaxEvents 5000 | Select-Object -ExpandProperty message
Stop-Transcript #>

# Removes everything except Apparatus and BCDStatus 
get-content  C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrors.txt |
select-string -SimpleMatch 'Apparatus','BCDStatus' |
set-content C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorsPrelim.txt 

if (!(Test-Path 'C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorsPrelim.txt')) { Remove-Item 'C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorFinal.txt' -ErrorAction SilentlyContinue }


# If status error prelim file exist, continue. if not, report "No New Errors"
$PrelimCheck= get-content "C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorsPrelim.txt"

if ($PrelimCheck.Count -gt 1) {$ContErrGen}
else
{"No Errors Detected"}

# Creates variable to parse entries specific to Apparatus and BCDStatus than outputs to StatusErrorsFormat.txt
# variable used for reference: $ParseRegexe = '(?<=(Apparatus|BCDStatus) \s*=\s*)[^ ]+'

if (Test-Path 'C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorsPrelim.TXT') {
    $i = 0
    $ContErrGen = Get-Content 'C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorsPrelim.TXT' |
        Select-String $ParseRegexe |
        ForEach-Object { $_.Matches.Value } |
        ForEach-Object { $_ -replace '\s', '' } |
        ForEach-Object {
            if ($i % 2) {
                ("$Keep,$($_)").Trim()
            } else {
                $keep = $_
            }
            $i++
        } |
        Select-Object -Unique > 'C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorFinal.txt'
} else {
   
}


# Import Txt to CSV with set headers and excluding type information using full path name  
If (Test-Path -Path 'C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorFinal.txt'){
Import-Csv "C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorFinal.txt" -delimiter "," -Header Apparatus, BCDStatus |
Export-Csv -NoTypeInformation "C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorResults.csv"
Import-CSV -Path C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorResults.csv | export-clixml C:\Windows\BCD\BCDMon\Logs\ErrorOutcome.xml
}else{
    
}
# Remove error entries when data pull turns to 0
if ((Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "DataPull") -eq '0'){
    Set-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "ErrorStatus" -Value "0"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "DataPull" -Value "0"  -PropertyType "String"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "NumberOfErrors" -Value "0"
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "LastSuccesfulDataPull" -Value "$TimeStamp"  -PropertyType "String"
    Remove-Item -Path "HKLM:\SOFTWARE\BCD\BCDMon\Errors" -Force -Verbose
    Remove-Item -Path "C:\Windows\BCD\BCDMon\Logs\ErrorOutcome.xml"
}
else {
"Awaiting Successful DataPull"
}

[int]$LinesInFile = 0
$reader = New-Object IO.StreamReader "C:\Windows\BCD\BCDMon\Logs\temp\StatusErrorFinal.txt"
while($reader.ReadLine() -ne $null){ $LinesInFile++ }
$reader.Close()
$reader.Dispose()

#add entries to registry
New-Item -Path "HKLM:\SOFTWARE\BCD\" -Name "StatMon" -Force

if ($LinesInFile -gt 0){
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "ErrorStatus" -Value "1"  -PropertyType "String" -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "NumberOfErrors" -Value "$LinesInFile"  -PropertyType "String" -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "LastErrorDiscovered" -Value "$TimeStamp"  -PropertyType "String" -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "DataPull" -Value "1"  -PropertyType "String" -Force
}
else {
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "ErrorStatus" -Value "0"  -PropertyType "String" -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "NumberOfErrors" -Value "0"  -PropertyType "String" -Force
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "LastErrorDiscovered" -ErrorAction SilentlyContinue
}

New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "UnitStatus" -Value "$UnitStatus"  -PropertyType "String" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "EmissaryStatus" -Value "$EmissaryStatus"  -PropertyType "String" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "MonitorCompleted" -Value "$TimeStamp"  -PropertyType "String" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "BCDStatVer" -Value "BCD-1.0"  -PropertyType "String" -Force

# Create entries for error Apparatus,BCDStatus
# Load the XML file
$XmlFile = "C:\Windows\BCD\BCDMon\Logs\ErrorOutcome.xml"

# Import the XML data as a PowerShell object
$XmlData = Import-Clixml -Path $XmlFile

# Iterate through the objects and create registry entries
$Path = "HKLM:\SOFTWARE\BCD\BCDMon\Errors"
New-Item -Path $Path -Force | Out-Null

$counter = 0

foreach ($Item in $XmlData) {
    $Apparatus = $Item.Apparatus
    $BCDStatus = $Item.BCDStatus

    Write-Host "Processing item $($counter + 1) - Apparatus: $Apparatus, BCDStatus: $BCDStatus"

    if (($Path -ne "") -and ($Apparatus -ne "")) {
        $PropertyExists = Get-ItemProperty -Path $Path -Name $Apparatus -ErrorAction SilentlyContinue
        if ($PropertyExists -ne $Null) {
            Remove-ItemProperty -Path $Path -Name "$Apparatus" -Force | out-null
        }
        New-ItemProperty -Path $Path -Name "$Apparatus" -Value $BCDStatus -PropertyType "String" -ErrorAction Stop -Force | Out-Null
    }

    $counter++
}

Write-Host "Processed $counter items."

#Check if Errors exist in XML
[int]$LinesInXML = 0
$reader = New-Object IO.StreamReader "C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorResults.xml"
 while($reader.ReadLine() -ne $null){ $LinesInXML++ }

$reader.Close()
$reader.Dispose()

if ($LinesInXML -gt 2){
Set-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "DataPull" -Value "1"
Get-Item –Path "C:\Windows\BCD\BCDMon\Logs\Temp\StatusErrorResults.xml" | 
Move-Item -Destination "C:\Windows\BCD\BCDMon\Logs\ErrorOutcome.xml"
}
else {
"No Errors Detected At This Time"
}

#Ensure XML and DataPull exist until changed to 0
[int]$LinesInXML = 0
$reader = New-Object IO.StreamReader "C:\Windows\BCD\BCDMon\Logs\ErrorOutcome.xml"
 while($reader.ReadLine() -ne $null){ $LinesInXML++ }

$reader.Close()
$reader.Dispose()

if ($LinesInXML -gt 2){
Set-ItemProperty -Path "HKLM:\SOFTWARE\BCD\BCDMon" -Name "DataPull" -Value "1"
}
else {
"No Errors Detected At This Time"
}

#Test active internet connection

function Test-InternetConnection {
    param (
        [Parameter(Mandatory=$true)]
        [string]$HostName
    )
    write-host "Test-InternetConnection called"
    $Port = 443
    $TimeoutMilliseconds = 1000

    $TCPClient = New-Object System.Net.Sockets.TcpClient
    try {
        $AsyncResult = $TCPClient.BeginConnect($HostName, $Port, $null, $null)
        $WaitResult = $AsyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $true)
        if ($TCPClient.Connected) {
            $TCPClient.Close()
            return 1
        } else {
            return 0
        }
    } catch {
        return 0
    }
}

$IP1 = "8.8.8.8"
$IP2 = "8.8.4.4"

$Result1 = Test-InternetConnection -HostName $IP1
$Result2 = Test-InternetConnection -HostName $IP2

$activeCon = if ($Result1 -eq 1 -or $Result2 -eq 1) { 1 } else { 0 }


Function LogActiveConnectionStatus {
    param (
        [int]$activeCon
    )

    $LogFolder = "C:\Windows\BCD\BCDMon\Logs"
    $LogFilePath = Join-Path -Path $LogFolder -ChildPath "ActiveLink_$(Get-Date -Format 'yyyyMMdd').log"

    $CurrentDateTime = Get-Date

    # Check if log file exists, create if it doesn't
    if (!(Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory | Out-Null
    }

    # Get the last log entry
    $lastLogEntry = Get-Content -Path $LogFilePath -Tail 1

    # If no previous entry or a new day has started, start a new uptime counter
    if (!$lastLogEntry -or (Get-Date $lastLogEntry.Split(" ")[0]) -lt (Get-Date).Date) {
        $lastLogEntry = "$CurrentDateTime $activeCon 00:00:00"
    }

    $lastEntryDateTime, $lastActiveCon, $lastUptime = $lastLogEntry.Split(" ")

    $LogEntry = ""

    # Log entry only if connection drops
    if ($activeCon -eq 0) {
        $LogEntry = "$CurrentDateTime Connection dropped"
    }

    # Check if a reboot event has occurred in the last 5 minutes
    $LastRebootEvent = Get-WinEvent -FilterHashtable @{LogName='System';ID=1074;StartTime=(Get-Date).AddMinutes(-5);EndTime=(Get-Date).AddMinutes(5)} -ErrorAction SilentlyContinue


    if ($LastRebootEvent) {
        $RebootTime = $LastRebootEvent.TimeCreated.ToString("MM/dd/yyyy HH:mm:ss")
        $LogEntry += "`r`n$RebootTime Machine was rebooted"
    }

    # Add the log entry only if a connection drop or a reboot event is detected
    if ($LogEntry) {
        Add-Content -Path $LogFilePath -Value $LogEntry
    }
}











#File Cleanup
$Reader=$null
Remove-item "C:\Windows\BCD\BCDMon\Logs\Temp" -Recurse

function LogDailyErrors {
    param (
        [string]$UnitStatus,
        [string]$EmissaryStatus,
        [int]$LinesInFile
    )

    $LogFolder = "C:\Windows\BCD\BCDMon\Logs"
    $LogFileName = "BCDLog_$(Get-Date -Format 'yyyyMMdd').xml"
    $LogFile = Join-Path -Path $LogFolder -ChildPath $LogFileName

    if (!(Test-Path $LogFolder)) {
        New-Item $LogFolder -ItemType Directory | Out-Null
    }

    if (!(Test-Path $LogFile)) {
        $XmlContent = '<?xml version="1.0" encoding="UTF-8"?><LogEntries></LogEntries>'
        $XmlContent | Set-Content -Path $LogFile
    }

    $XmlDocument = New-Object System.Xml.XmlDocument
    $XmlDocument.Load($LogFile)

    # Get the values from the registry
    $RegistryPath = "HKLM:\SOFTWARE\BCD\BCDMon"
    $UnitStatus = (Get-ItemProperty -Path $RegistryPath -Name "UnitStatus").UnitStatus
    $EmissaryStatus = (Get-ItemProperty -Path $RegistryPath -Name "EmissaryStatus").EmissaryStatus
    $UID = [guid]::NewGuid().ToString()

    # Store the values in the XML
    $LogEntry = $XmlDocument.CreateElement("LogEntry")

    $BCDNameElement = $XmlDocument.CreateElement("BCDName")
    $BCDNameElement.InnerText = $bcdNam  
    $LogEntry.AppendChild($BCDNameElement)

    $UnitStatusElement = $XmlDocument.CreateElement("UnitStatus")
    $UnitStatusElement.InnerText = $UnitStatus
    $LogEntry.AppendChild($UnitStatusElement)

    $EmissaryStatusElement = $XmlDocument.CreateElement("EmissaryStatus")
    $EmissaryStatusElement.InnerText = $EmissaryStatus
    $LogEntry.AppendChild($EmissaryStatusElement)

    $ActiveConElement = $XmlDocument.CreateElement("InternetConnection")
    $ActiveConElement.InnerText = $activeCon
    $LogEntry.AppendChild($ActiveConElement)

    $NumberOfErrorsElement = $XmlDocument.CreateElement("NumberOfErrors")
    $NumberOfErrorsElement.InnerText = $LinesInFile
    $LogEntry.AppendChild($NumberOfErrorsElement)

    # Only append error entries if LinesInFile is greater than 0
    if ($LinesInFile -gt 0) {
        $ErrorsNode = $XmlDocument.CreateElement("Errors")
        $LogEntry.AppendChild($ErrorsNode)

        $filePath = "C:\Windows\BCD\BCDMon\Logs\ErrorOutcome.xml"
        $errorCount = 0

        if (Test-Path $filePath) {
            $xmlContent = [xml](Get-Content $filePath)
            $errorCount = $xmlContent.Objs.Obj.Count

            if ($errorCount -gt 0) {
                foreach ($error in $xmlContent.Objs.Obj) {
                    $errorNode = $XmlDocument.CreateElement("Error")
                    $ErrorsNode.AppendChild($errorNode)

                    $deviceNode = $XmlDocument.CreateElement("Apparatus")
                    $deviceNode.InnerText = $error.MS.S | Where-Object { $_.N -eq 'Apparatus' } | Select-Object -ExpandProperty '#text'
                    $errorNode.AppendChild($deviceNode)

                    $BCDStatusNode = $XmlDocument.CreateElement("BCDStatus")
                    $BCDStatusNode.InnerText = $error.MS.S | Where-Object { $_.N -eq 'BCDStatus' } | Select-Object -ExpandProperty '#text'
                    $errorNode.AppendChild($BCDStatusNode)
                }
            }
        }
    }

    $UIDElement = $XmlDocument.CreateElement("UID")
    $UIDElement.InnerText = New-UniqueId
    $LogEntry.AppendChild($UIDElement)

    $BCDStatVerElement = $XmlDocument.CreateElement("BCDStatVer")
    $BCDStatVerElement.InnerText = "BCD-1.0"
    $LogEntry.AppendChild($BCDStatVerElement)

    $MonitorCompletedElement = $XmlDocument.CreateElement("MonitorCompleted")
    $MonitorCompletedElement.InnerText = $TimeStampEST
    $LogEntry.AppendChild($MonitorCompletedElement)

    $TimeZoneElement = $XmlDocument.CreateElement("TimeZone")
    $TimeZoneElement.InnerText = $TimeZone
    $LogEntry.AppendChild($TimeZoneElement)

    # Append the log entry to the document
    $XmlDocument.SelectSingleNode("//LogEntries").AppendChild($LogEntry) | Out-Null

    try {
        $XmlDocument.Save($LogFile)
    }
    catch {
        Write-Host "Error appending to log file: $_"
    }
}




function ArchiveDailyLog {
    $Today = Get-Date
    $TodayDate = $Today.ToString("yyyyMMdd")
    $CatalogFolder = "C:\Windows\BCD\BCDMon\Logs\Catalog"
    $LogFolder = "C:\Windows\BCD\BCDMon\Logs"

    if (!(Test-Path $CatalogFolder)) {
        New-Item -ItemType Directory -Path $CatalogFolder | Out-Null
    }

    Get-ChildItem -Path $LogFolder -Filter "BCDLog_*.xml" | ForEach-Object {
        $LogFileDate = $_.Name.Substring(8, 8)
        if ($LogFileDate -lt $TodayDate) {
            $ArchiveFile = Join-Path -Path $CatalogFolder -ChildPath $_.Name
            Move-Item -Path $_.FullName -Destination $ArchiveFile -Force
        }
    }

    Get-ChildItem -Path $LogFolder -Filter "ActiveLink_*.log" | ForEach-Object {
        $LogFileDate = $_.Name.Substring(17, 8)
        if ($LogFileDate -lt $TodayDate) {
            $ArchiveFile = Join-Path -Path $CatalogFolder -ChildPath $_.Name
            Move-Item -Path $_.FullName -Destination $ArchiveFile -Force
        }
    }

    $CutoffDate = (Get-Date).AddDays(-45)
    Get-ChildItem -Path $CatalogFolder -Filter "BCDLog_*.xml" | ForEach-Object {
        if ($_.CreationTime -lt $CutoffDate) {
            Remove-Item -Path $_.FullName -Force
        }
    }

    $CutoffDate = (Get-Date).AddDays(-45)
    Get-ChildItem -Path $CatalogFolder -Filter "ActiveLink_*.log" | ForEach-Object {
        if ($_.CreationTime -lt $CutoffDate) {
            Remove-Item -Path $_.FullName -Force
        }
    }

}

LogDailyErrors -UnitStatus $UnitStatus -EmissaryStatus $EmissaryStatus -LinesInFile $LinesInFile

LogActiveConnectionStatus -activeCon $activeCon


ArchiveDailyLog

# Stop-Transcript

start-sleep -s 300