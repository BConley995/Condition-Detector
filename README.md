Condition Detector
Condition Detector is a PowerShell script that performs error detection, logging, and cleanup tasks primarily focusing on specific files, internet connection status, and system logs.

Key Features
Error Monitoring: Checks specific files for errors and logs these errors for future review.
Internet Connection Monitoring: Tests the internet connection status by trying to establish a connection with Google's DNS servers.
Logging: Logs errors and internet connection status on a daily basis in an XML format.
File Cleanup: Regularly cleans up temporary folders to maintain an uncluttered file system.
Log Archiving: Archives daily logs and removes log files older than 45 days.

Usage
To use this script, you need to have sufficient permissions to read and write files and registry keys on the system. The script can be run directly on a PowerShell console or scheduled to run at specific intervals using a task scheduler.

Note: There are some variables like $bcdNam, $TimeStampEST, and $TimeZone that are used in the script but are not defined in the provided context. Make sure these variables are properly initialized before running the script.

Output
The script creates logs in the C:\Windows\BCD\BCDMon\Logs directory, containing the status of the unit, status of the emissary, the status of internet connection, number of errors detected, and details about the errors.

Customization
You may need to modify the paths, file names, and registry keys in the script according to your system's configuration.

Contributions
Contributions are welcome. Please make sure to update tests as appropriate.
