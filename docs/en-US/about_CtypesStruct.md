# Ctypes Structs
## about_CtypesStruct

# SHORT DESCRIPTION
It is very common for a C based API to use structs as arguments when dealing with complex data but there is no easy way to define a custom struct in PowerShell without restoring to `Add-Type`.
This modules provides a helper function to define these structs for you.

# LONG DESCRIPTION
PowerShell currently supports defining classes using the `class` keyword but it has no way to define a struct type as well as the layout/field information that might be needed when using that struct as an argument for a PInvoke member.
The `ctypes_struct` function supplied by this module is an alias for [New-Ctypes-Struct](./New-CtypesStruct.md) and is designed to give a similar interface as the `class` keyword in PowerShell but for defining structs.

The [SECURITY_ATTRIBUTES struct](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/aa379560(v=vs.85)) is a simple struct used in various Windows PInvoke functions and its definition is:

```c
typedef struct _SECURITY_ATTRIBUTES {
  DWORD  nLength;
  LPVOID lpSecurityDescriptor;
  BOOL   bInheritHandle;
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;
```

There are 3 fields in this struct, an int, pointer, and boolean which can easily be represented in dotnet.
To define this struct using `ctypes_struct`, take the fields that are defined and write it inside the scriptblock with the syntax `[FieldType]$FieldName` like so:

```powershell
ctypes_struct SECURITY_ATTRIBUTES {
    [int]$Length
    [IntPtr]$SecurityDescriptor
    [bool]$InheritHandle
}
```

By default if no type is specified, the type used is `[IntPtr]`.
Once defined the struct can be created just like any other type in PowerShell:

```powershell
$sa = [SECURITY_ATTRIBUTES]::new()
$sa.Length = [System.Runtime.InteropServices.Marshal]::SizeOf($sa)
```

It can also be defined by "casting" a hashtable with the field names and values in an easier short hand:

```powershell
$sa = [SECURITY_ATTRIBUTES]@{
    Length = [System.Runtime.InteropServices.Marshal]::SizeOf([type][SECURITY_ATTRIBUTES])
}
```

The scriptblock used in `ctypes_struct` is designed to be very simple and only allow lines that contain `[type]$Name` with an optional `[MarshalAs]` or `[FieldOffset]` attribute before the type.
The scriptblock isn't invoked in any way, it is parsed at runtime to extract the lines and build the struct based on what was found.
It is possible to define a struct with the same name, the caveat being the original definition can no longer be referenced by `[STRUCT_TYPE]` anymore even if it remains loaded.
Only the last defined struct of the same name will be referred to by that name.

# StructLayout Attribute
Typically when defining a struct for use in a PInvoke function, the [StructLayoutAttribute](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.structlayoutattribute?view=net-7.0) is used to tell dotnet how to marshal the struct value when passing by reference and calculating the size.
By default `ctypes_struct` applies the attribute `[StructLayout(LayoutKind.Sequential)]` to the struct it defines.
This can be controlled using the following parameters:

* `-CharSet`
* `-LayoutKind`
* `-Pack`

These attributes corresponds to the same fields in the `StructLayout` attribute.
For example, to define a struct with the Explicit layout, charset of Unicode, and a pack size of 8, the following is done:

```powershell
ctypes_struct -CharSet Unicode -LayoutKind Explicit -Pack 8 {
    ...
}
```

# Field Attributes
Each field in the struct can be defined with 2 different attributes:

* [MarshalAsAttribute](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshalasattribute?view=net-7.0)
* [FieldOffsetAttribute](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.fieldoffsetattribute?view=net-7.0)

To define a field with one of these attributes, just place it before the type definition:

```powershell
ctypes_struct FIELD_MARSHAL_AS {
    [MarshalAs('LPWStr')][string]$StringField
}

ctypes_struct FIELD_OFFSET_STRUCT -LayoutKind Explicit {
    [FieldOffset(0)][int]$IntFieldAt0
    [FieldOffset(4)][int]$IntFieldAt4
}
```

The `FieldOffset` is a simple attribute that only accepts an integer value being the field offset to use.
The `MarshalAs` attribute accepts either the [UnmanagedType](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.unmanagedtype?view=net-7.0) enum name as a string or an integer representing the unmanaged type value.
It also accepts the `ArraySubType` and `SizeConst` values with `ArraySubType` being the `UnmanagedType` string/int value and `SizeConst` being the int representing the number of elements in the array field value.
Here is a more complex `MarshalAs` field example with those optional values:

```powershell
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
    [MarshalAs('ByValArray', SizeConst=1)][LUID_AND_ATTRIBUTES[]]$Privileges
}
```

_Note: Due to limitations in the scriptblock validator, the unmanaged type value must be a string constant or int, it cannot be the enum::value._

# Using Pointer to a Struct
While some functions accept the struct value itself being passed by reference, many functions require a pointer to a struct.
For example the [CreateProcessW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw) and required structures have the following signatures:

```c
BOOL CreateProcessW(
  [in, optional]      LPCWSTR               lpApplicationName,
  [in, out, optional] LPWSTR                lpCommandLine,
  [in, optional]      LPSECURITY_ATTRIBUTES lpProcessAttributes,
  [in, optional]      LPSECURITY_ATTRIBUTES lpThreadAttributes,
  [in]                BOOL                  bInheritHandles,
  [in]                DWORD                 dwCreationFlags,
  [in, optional]      LPVOID                lpEnvironment,
  [in, optional]      LPCWSTR               lpCurrentDirectory,
  [in]                LPSTARTUPINFOW        lpStartupInfo,
  [out]               LPPROCESS_INFORMATION lpProcessInformation
);

typedef struct _SECURITY_ATTRIBUTES {
  DWORD  nLength;
  LPVOID lpSecurityDescriptor;
  BOOL   bInheritHandle;
} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

typedef struct _STARTUPINFOW {
  DWORD  cb;
  LPWSTR lpReserved;
  LPWSTR lpDesktop;
  LPWSTR lpTitle;
  DWORD  dwX;
  DWORD  dwY;
  DWORD  dwXSize;
  DWORD  dwYSize;
  DWORD  dwXCountChars;
  DWORD  dwYCountChars;
  DWORD  dwFillAttribute;
  DWORD  dwFlags;
  WORD   wShowWindow;
  WORD   cbReserved2;
  LPBYTE lpReserved2;
  HANDLE hStdInput;
  HANDLE hStdOutput;
  HANDLE hStdError;
} STARTUPINFOW, *LPSTARTUPINFOW;

typedef struct _PROCESS_INFORMATION {
  HANDLE hProcess;
  HANDLE hThread;
  DWORD  dwProcessId;
  DWORD  dwThreadId;
} PROCESS_INFORMATION, *PPROCESS_INFORMATION, *LPPROCESS_INFORMATION;
```

The `lpProcessAttributes` and `lpThreadAttributes` accept an `LPSECURITY_ATTRIBUTES` which in the structs definition is defined as a pointer `SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;`.
The same applies to `lpStartupInfo` and `lpProcessInformation` being pointers to the structs themselves.
This means that instead of passing the struct by value, they must be passed by reference.
To pass a struct by reference, simply use the `[ref]` attribute on the variable when calling the function, or on the type when declaring the function explicitly.
Here is a full example of calling `CreateProcess` using this module:

```powershell
ctypes_struct SECURITY_ATTRIBUTES {
    [int]$Length
    [IntPtr]$SecurityDescriptor
    [bool]$InheritHandle
}

ctypes_struct STARTUPINFOW -CharSet Unicode {
    [int]$CB
    [MarshalAs('LPWStr')][string]$Reserved
    [MarshalAs('LPWStr')][string]$Desktop
    [MarshalAs('LPWStr')][string]$Title
    [int]$X
    [int]$Y
    [int]$XSize
    [int]$YSize
    [int]$XCountChars
    [int]$YCountChars
    [int]$FillAttribute
    [int]$Flags
    [short]$ShowWindow
    [short]$Reserved2
    [IntPtr]$Reserved3
    [IntPtr]$StdInput
    [IntPtr]$StdOutput
    [IntPtr]$StdError
}

ctypes_struct PROCESS_INFORMATION -LayoutKind Sequential {
    [IntPtr]$Process
    [IntPtr]$Thread
    [int]$Pid
    [int]$Tid
}

# There are more options but limited here for the sake of brevity
[Flags()] enum ProcessCreationFlags {
    NONE = 0x00000000
    CREATE_NEW_CONSOLE = 0x00000010
    CREATE_UNICODE_ENVIRONMENT = 0x00000400
}

$kernel32 = New-CtypesLib Kernel32.dll

# This step is optional and am example of how to define a pointer to struct
$kernel32.Returns([bool]).SetLastError().CharSet('Unicode').CreateProcessW = [Ordered]@{
    # LPCWSTR is a constant, can use the normal string type
    lpApplicationName = [string]

    # LPWSTR is not constant, need to use StringBuilder for this as the
    # function can mutate the string which isn't allowed by [string]
    lpCommandLine = [System.Text.StringBuilder]

    # LPSECURITY_ATTRIBUTES is a pointer to SECURITY_ATTRIBUTES, use [ref]
    lpProcessAttributes = [ref][SECURITY_ATTRIBUTES]

    # Using [IntPtr] is also allowed as that allows the caller to do
    # [IntPtr]::Zero to specify NULL
    lpThreadAttributes = [IntPtr]

    bInheritHandles = [bool]

    # Can also be [int] but defining an enum gives completion support as well
    # as specify the value as a string. WinPS (5.1) must use [int] here instead
    # as it cannot reference an enum type defined in PowerShell.
    dwCreationFlags = [ProcessCreationFlags]

    # LPVOID is the same as IntPtr
    lpEnvironment = [IntPtr]

    lpCurrentDirectory = [string]

    lpStartupInfo = [ref][STARTUPINFOW]

    lpProcessInformation = [ref][PROCESS_INFORMATION]
}

$procSa = [SECURITY_ATTRIBUTES]@{
    Length = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][SECURITY_ATTRIBUTES])
    InheritHandle = $true
}
$si = [STARTUPINFOW]@{
    CB = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][STARTUPINFOW])
}
$pi = [PROCESS_INFORMATION]::new()

$commandLine = [System.Text.StringBuilder]::new("powershell.exe -NoExit -Command 'hi'")

# The Returning, SetLastError, and CharSet is not needed if explicitly defined above
$res = $kernel32.Returns([bool]).SetLastError().CharSet('Unicode').CreateProcessW(
    "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    $commandLine,
    [ref]$procSa,
    [IntPtr]::Zero,
    $false,
    [ProcessCreationFlags]'CREATE_NEW_CONSOLE, CREATE_UNICODE_ENVIRONMENT',
    [IntPtr]::Zero,
    "C:\Windows",
    [ref]$si,
    [ref]$pi
)
if (-not $res) {
    throw [System.ComponentModel.Win32Exception]$kernel32.LastError
}

$kernel32.CloseHandle($pi.Process)
$kernel32.CloseHandle($pi.Thread)
```

Two major things to point out here

* Windows PowerShell 5.1 cannot reference an enum defined in PowerShell using the `enum` syntax
* PowerShell 6+ copies the PowerShell enum when declared into the struct assembly

A consequence of the second point is that when you declare a field with an enum defined in PowerShell in a `ctypes_struct`, the enum will now persist globally rather than be collected when it goes out of scope.
