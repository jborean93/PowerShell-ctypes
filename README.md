# Ctypes

[![Test workflow](https://github.com/jborean93/PowerShell-ctypes/workflows/Test%20Ctypes/badge.svg)](https://github.com/jborean93/PowerShell-ctypes/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jborean93/PowerShell-Ctypes/branch/main/graph/badge.svg?token=b51IOhpLfQ)](https://codecov.io/gh/jborean93/PowerShell-Ctypes)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Ctypes.svg)](https://www.powershellgallery.com/packages/Ctypes)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jborean93/PowerShell-ctypes/blob/main/LICENSE)

Provides a unique way to call native APIs in PInvoke in PowerShell.
It is modelled after the Python [ctypes library](https://docs.python.org/3/library/ctypes.html).

See [ctypes index](docs/en-US/Ctypes.md) for more details.

## Examples

_Note: All these examples use the generics to specify the return method which is pwsh 7.3+ only. Use `.Returns([type])` instead for older versions._

### Calling CreateFileW directly

```powershell
$k32 = New-CtypesLib Kernel32.dll
$fh = $k32.CharSet('Unicode').SetLastError().CreateFileW[Microsoft.Win32.SafeHandles.SafeFileHandle](
    "\\?\C:\temp\test.txt",
    [System.Security.AccessControl.FileSystemRights]'FullControl',
    [System.IO.FileShare]::Read,
    $null,
    [System.IO.FileMode]::Create,
    0,  # FlagsAndAttributes
    $null)
if ($fh.IsInvalid -eq [IntPtr](-1)) {
    throw [System.ComponentModel.Win32Exception]$k32.LastError
}

$fs = [System.IO.FileStream]::new($fh, [System.IO.FileAccess]::ReadWrite)
...
```

Calls [CreateFileW](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-createfilew) directly with the long path prefix and creates a filestream on the returned object.
It also wraps the raw handle in a `SafeFileHandle` making it easy to dispose the object when not needed anymore.

### Using a struct and references

```powershell
[int]$processId = Read-Host -Prompt 'What pid do you wish to inspect'
$k32 = New-CtypesLib Kernel32.dll
$advapi = New-CtypesLib Advapi32.dll

ctypes_struct LUID {
    [int]$LowPart
    [int]$HighPart
}

ctypes_struct LUID_AND_ATTRIBUTES {
    [LUID]$Luid
    [int]$Attributes
}

ctypes_struct TOKEN_PRIVILEGES {
    [int]$PrivilegeCount
    [MarshalAs('LPArray', SizeConst=1)][LUID_AND_ATTRIBUTES[]]$Privileges
}

$proc = $k32.SetLastError().OpenProcess[IntPtr](
    0x400,  # PROCESS_QUERY_INFORMATION
    $false,
    $processId)
if ($proc -eq [IntPtr]::Zero) {
    throw [System.ComponentModel.Win32Exception]$k32.LastError
}

$handle = [IntPtr]::Zero
try {
    $res = $advapi.SetLastError().OpenProcessHandle[bool](
        $proc,
        [System.Security.Principal.TokenAccessLevels]::Query,
        [ref]$handle)
    if (-not $res) {
        throw [System.ComponentModel.Win32Exception]$advapi.LastError
    }

}
finally {
    if ($handle -ne [IntPtr]::Zero) {
        $k32.CloseHandle[void]($handle)
    }
    $k32.CloseHandle[void]($proc)
}
```

This is a more complex example that uses reference types and structs to get the token privileges of another process handle.

### Gettings libc version

```powershell
$libc = New-CtypesLib libc
[System.Runtime.InteropServices.Marshal]::PtrToStringUTF8(
    $libc.gnu_get_libc_version[IntPtr]())
```

_Note: This can't return a string directly as dotnet will try and free the memory which cannot be done._

## Requirements

These cmdlets have the following requirements

* PowerShell v5.1 or newer

## Installing

The easiest way to install this module is through [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/overview).

You can install this module by running;

```powershell
# Install for only the current user
Install-Module -Name Ctypes -Scope CurrentUser

# Install for all users
Install-Module -Name Ctypes -Scope AllUsers
```

## Contributing

Contributing is quite easy, fork this repo and submit a pull request with the changes.
To build this module run `.\build.ps1 -Task Build` in PowerShell.
To test a build run `.\build.ps1 -Task Test` in PowerShell.
This script will ensure all dependencies are installed before running the test suite.
