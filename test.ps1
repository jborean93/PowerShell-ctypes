$ErrorActionPreference = 'Stop'

$kernel32 = Get-CtypesLib Kernel32.dll
$kernel32.OpenProcess[IntPtr](0x400, $false, $pid)

# ctypes_struct STARTUPINFOW -LayoutKind Sequential -CharSet Unicode {
#     [int]$CB
#     [IntPtr]$Reserved
#     [IntPtr]$Desktop
#     [IntPtr]$Title
#     [int]$X
#     [int]$Y
#     [int]$XSize
#     [int]$YSize
#     [int]$XCountChars
#     [int]$YCountChars
#     [int]$FillAttribute
#     [int]$Flags
#     [short]$ShowWindow
#     [short]$Reserved2
#     [IntPtr]$Reserved3
#     [IntPtr]$StdInput
#     [IntPtr]$StdOutput
#     [IntPtr]$StdError
# }

# ctypes_struct PROCESS_INFORMATION -LayoutKind Sequential {
#     [IntPtr]$Process
#     [IntPtr]$Thread
#     [int]$Pid
#     [int]$Tid
# }

# $si = [STARTUPINFOW]::new()
# $si.CB = [System.Runtime.InteropServices.Marshal]::SizeOf($si)
# $pi = [PROCESS_INFORMATION]::new()

# $commandLine = [System.Text.StringBuilder]::new("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoExit -Command 'hi'")
# $kernel32 = Get-CtypesLib Kernel32.dll
# $res = $kernel32.Returning([bool]).SetLastError().CharSet('Unicode').CreateProcessW(
#     $kernel32.MarshalAs("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe", "LPWStr"),
#     $commandLine,
#     [IntPtr]::Zero,
#     [IntPtr]::Zero,
#     $false,
#     0x00000410, # CREATE_UNICODE_ENVIRONMENT | CREATE_NEW_CONSOLE
#     [IntPtr]::Zero,
#     $kernel32.MarshalAs("C:\temp", "LPWStr"),
#     [ref]$si,
#     [ref]$pi
# )
# if (-not $res) {
#     throw [System.ComponentModel.Win32Exception]$kernel32.LastError
# }

# $kernel32.CloseHandle($pi.Process)
# $kernel32.CloseHandle($pi.Thread)
