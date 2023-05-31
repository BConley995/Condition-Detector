# Condition Detector

Condition Detector is a PowerShell script intended for error detection, logging, and cleanup tasks. Its primary focus is on specific files, internet connection status, and system logs.

## Key Features

- **Error Monitoring**: Monitors specific files for errors and logs these errors for subsequent review.
- **Internet Connection Monitoring**: Evaluates the status of the internet connection by attempting to connect to Google's DNS servers.
- **Logging**: Logs errors and internet connection status daily in an XML format.
- **File Cleanup**: Conducts routine cleanup of temporary folders to maintain an uncluttered file system.
- **Log Archiving**: Archives daily logs and deletes log files that are older than 45 days.

## Usage

To utilize this script, you must have appropriate permissions to read and write files and registry keys on the system. The script can be executed directly in a PowerShell console or scheduled to run at specific intervals using a task scheduler.

> **Note**: There are certain variables like `$bcdNam`, `$TimeStampEST`, and `$TimeZone` that are employed in the script but are not defined in the provided context. Make sure these variables are properly initialized before running the script.

## Output

The script generates logs in the `C:\Windows\BCD\BCDMon\Logs` directory, detailing the status of the unit, emissary status, internet connection status, count of detected errors, and specifics regarding these errors.

## Customization

You may need to modify the paths, file names, and registry keys in the script based on your system's configuration.

## Contributions

Contributions are warmly welcomed. Please ensure to update tests as applicable.
