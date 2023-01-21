# Ctypes Interface
## about_CtypesInterface

# SHORT DESCRIPTION
The ctypes library object returned by [New-CtypesLib](./New-CtypesLib.md) is a special object that is designed to dynamically build the PInvoke extern method when requested based on the arguments provided.
It does this through reflection and analysing the existing values provided before building the `PSCodeMethod` which ultimately calls that newly creating PInvoke method.

# LONG DESCRIPTION
There are 2 ways of defining a PInvoke method to call in a library:

* Calling the method directly with the arguments desired

* Explicitly defining a new property with an array or ordered dict defining the types needed for the method

The [OpenProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess) function has the following signature.

```c
HANDLE OpenProcess(
  [in] DWORD dwDesiredAccess,
  [in] BOOL  bInheritHandle,
  [in] DWORD dwProcessId
);
```

Invoking it directly without pre-defining the signature is possible by using variables with the same types:

```powershell
$kernel32 = New-CtypesLib kernel32.dll
$kernel32.OpenProcess[IntPtr](0x400, $false, 1234)
```

_Note: The return type was defined using the new generics syntax added in PowerShell 7.3. Older PowerShell versions should use the `.Returns([Type])` method instead.

Once called, the signature for this function is stored on the `$kernel32` object and can be viewed with `Get-Member`.
Any other functions called will also appear here.

To predefine the function before it is called, simply assign an array or ordered dictionary with the parameter types needed.
For example using an array looks like

```powershell
$kernel32.Returns([IntPtr]).OpenProcess = @(
    [int],
    [bool],
    [int]
)
```

An ordered dictionary can also be used to give a label to the arguments:

```powershell
$kernel32.Returns([IntPtr]).OpenProcess = [Ordered]@{
    DesiredAccess = [int]
    InheritHandle = [bool]
    ProcessId = [int]
}
```

As shown on the method definition, these field names appear in the overload defition rather than a generic arg name

```powershell
$kernel32 | Get-Member -Name OpenProcess

   TypeName: Ctypes.Library

Name        MemberType Definition
----        ---------- ----------
OpenProcess CodeMethod static System.IntPtr OpenProcess(psobject lib, int DesiredAccess, bool InheritHandle, int ProcessId)
```

It is also possible to use `$null` as a representation for `[IntPtr]::Zero`.
If `$null` was used as a type value when defining a signature, or used as an argument for a method without a predefined signature, the argument type is `IntPtr` and the value becomes `IntPtr.Zero`.
This makes it possible to use `$null` as a shorthand for `[IntPtr]::Zero`.
Take [CloseHandle](https://learn.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-closehandle) as an example.

```c
BOOL CloseHandle(
  [in] HANDLE hObject
);
```

This can be used like

```powershell
$lib.Returns([bool]).CloseHandle($null)

# Both of these are the same when pre-defining a function

$lib.Returns([bool]).CloseHandle = @($null)
$lib.Returns([bool]).CloseHandle = @([IntPtr])
```

Predefining the argument types is useful because we can take advantage of PowerShell's casting behaviour to ensure the correct type is used rather than what is the value is when called.
For example, using an explicit enum type allows the caller to use the enum string name rather than the enum or integer value itself.

It is important to note that once a method has been defined or called on a library object, the signature cannot be changed.
Trying to use a new return type or any one of the special attributes documented below will only work when the method is explicitly defined for the first time or, if not explicitly defined, when it is first called.
To use a new method signature, simply create a new library object in another variable and try again.

# Return Types
By default all PInvoke functions called have a return type of `[int]`.
If the function does not normally return an int this value may have no meaning or be unusable.
There are two ways to define an explicit return type for a PInvoke function.
The first is universal and works across all PowerShell versions and when pre-defining the method signature through the `Returns` function.

```powershell
$lib.Returns([IntPtr]).MyFunction($true)

# or

$lib.Returns([IntPtr]).MyFunction = @([bool])
```

This will call the `MyFunction` PInvoke method on the native library `$lib` represents and defines the return value as an `IntPtr`.

The alternative way is to use the new PowerShell generics featured shipped in PowerShell 7.3.
This only works when calling the function directly for the first time without it being pre-defined.

```powershell
# PowerShell 7.3+ only
$lib.MyFunction[IntPtr]($true)
```

Once a function has been defined or called once, it is not possible to change the return type.
Using `Returns` or the generic type invocation after it has been defined will not change the return type and is effectively a no-op.

To silence any output using the `[void]` type like so:

```powershell
$lib.Returns([void]).MyFunction($true)

# or

$lib.MyFunction[void]($true)
```

# Reference Types
It is common to encounter a PInvoke method that uses a pointer as an argument.
One way is to pass through an `[IntPtr]` typed value that points to the value but another option is to pass the value by reference.
In PowerShell this is achieved by using the `[ref]` attribute.

For example the function [OpenProcessToken](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocesstoken) has the following signature

```c
BOOL OpenProcessToken(
  [in]  HANDLE  ProcessHandle,
  [in]  DWORD   DesiredAccess,
  [out] PHANDLE TokenHandle
);
```

The `TokenHandle` argument uses a `PHANDLE` type which is a pointer to a `HANDLE` which in C# is a pointer to an `IntPtr`.
Pre-defining this signature would look like

```powershell
$advapi32 = New-CtypesLib Advapi32.dll
$advapi32.Returns([bool]).OpenProcessToken = [Ordered]@{
    ProcessHandle = [IntPtr]
    DesiredAccess = [System.Security.Principal.TokenAccessLevels]
    TokenHandle = [ref][IntPtr]
}
```

Calling this method would look like

```powershell
$token = [IntPtr]::Zero
$advapi32.OpenProcessToken(
    $procHandle,
    'Query',
    [ref]$token)
```

_Note: The definition of this function is not strictly required, if a function is not defined but invoked directory, a reference type is still used when the argument was passed with `[ref]`._

# DllImport Attributes
When defining a PInvoke function in C# code the [DllImportAttribute](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.dllimportattribute?view=net-7.0) is used to define the metadata needed for C# to hook into native function.
This attribute can be used to define the following:

* The dll/lib name
* The calling convention
* The character set used for string marshaling
* The function name to be called in the dll/lib
* Whether to store the native last error code value after calling

It is possible to also set the above using the Ctypes library object created by `New-CtypesLib` using the following methods on that object:

|DllImport Value|Ctypes Lib Method|Default|
|-|-|-|
|Dll/Lib Name|Part of `New-CtypesLib LibNamed.dll`|Mandatory|
|CallingConvention|`$lib.CallingConvetention($cc)`|Winapi (StdCall on Windows and Cdecl on Linux)|
|CharSet|`$lib.CharSet($cs)`|Auto|
|EntryPoint|`$lib.EntryPoint($e)`|Uses the method name|
|SetLastError|`$lib.SetLastError()`|False|

All the functions return the same library object so can be chained together.
For example to set the char set and enable last error caching the following can be used:

```powershell
$res = $lib.CharSet('Unicode').SetLastError().CreateFileW[IntPtr](
    "C:\temp\test.txt",
    0,
    [System.IO.FileShare]::Read,
    [IntPtr]::Zero,
    [System.IO.FileMode]::Create,
    0,
    [IntPtr]::Zero)
if ($res -eq [IntPtr](-1)) {
    throw [System.ComponentModel.Win32Exception]$lib.LastError
}
```

The character set will use `[System.Runtime.InteropServices.CharSet]::Unicode`, store the last error code set by the function and return the value as an `IntPtr`.
On a failure it retrieves the error code through the `LastError` property on the object.
Do not use `[System.Runtime.InteropServices.Marshal]::GetLastWin32Error()` as that value could have been mutated by the PowerShell engine between statements. The `LastError` property is retrieved using that code but at a stage where PowerShell may not have overidden it.

# MarshalAs Attributes
Another attribute used in PInvoke definitions is the ability to mark specific arguments with a [MarshalAsAttribute](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.marshalasattribute?view=net-7.0).
This attribute can be used to control how strings are marshaled as, or define array marshaling behaviour.
To mark an argument with this attribute, use the `$lib.MarshalAs($obj, $unmanagedType)` function.
This function adds a hidden PSNoteProperty to the object and is applied to the PInvoke definition when it's dynamically created for the first time.

_Note: Just like any other method metadata value, this only applies when the method is first defined. If used on a method already defined, it will be silently ignored._

Using the `CreateFileW` example above, here is how to mark the first argument with `[MarshalAs(UnmanagedType.LPWStr)]`:

```powershell
$lib.Returns([IntPtr]).SetLastError().CreateFileW = @(
    $lib.MarshalAs([string], "LPWStr"),
    [int],
    [System.IO.FileShare],
    [IntPtr],
    [System.IO.FileMode],
    [int],
    [IntPtr]
)

# Or with named arguments

$lib.Returns([IntPtr]).SetLastError().CreateFileW = [Ordered]@{
    lpFileName = $lib.MarshalAs([string], "LPWStr")
    dwDesiredAccess = [int]
    dwShareMode = [System.IO.FileShare]
    lpSecurityAttributes = [IntPtr]
    dwCreationDisposition = [System.IO.FileMode]
    dwFlagsAndAttributes = [int]
    hTemplateFile = [IntPtr]
}

# Or without an explicit signature

$lib.SetLastError().Returns([IntPtr]).CreateFileW(
    $lib.MarshalAs("C:\temp\test.txt", "LPWStr"),
    0,
    [System.IO.FileShare]::Read,
    [IntPtr]::Zero,
    [System.IO.FileMode]::Create,
    0,
    [IntPtr]::Zero)
```

# Viewing Existing Definitions
Once a method has been pre-defined or when it is first called, the method is added as a `CodeMethod` member of the underlying library object.
This ensures that the method does not need to be generated every time it is called and it provides an easy way to inspect the signature that was generated.
As this is just any member on the Extended Type System (ETS) of the object, it can be retrieved using `Get-Member` or just by accessing the method like a property.
For example

```powershell
$lib = New-CtypesLib Kernel32.dll
$lib.Returns([IntPtr]).SetLastError().CreateFileW = [Ordered]@{
    lpFileName = $lib.MarshalAs([string], "LPWStr")
    dwDesiredAccess = [int]
    dwShareMode = [System.IO.FileShare]
    lpSecurityAttributes = [IntPtr]
    dwCreationDisposition = [System.IO.FileMode]
    dwFlagsAndAttributes = [int]
    hTemplateFile = [IntPtr]
}

$lib.CreateFileW

# CodeReference       : IntPtr CreateFileW(System.Management.Automation.PSObject, System.String, Int32, System.IO.FileShare, IntPtr, System.IO.FileMode, Int32, IntPtr)
# MemberType          : CodeMethod
# OverloadDefinitions : {static System.IntPtr CreateFileW(psobject lib, string lpFileName, int dwDesiredAccess, System.IO.FileShare dwShareMode, System.IntPtr lpSecurityAttributes,
#                       System.IO.FileMode dwCreationDisposition, int dwFlagsAndAttributes, System.IntPtr hTemplateFile)}
# TypeNameOfValue     : System.Management.Automation.PSCodeMethod
# Value               : static System.IntPtr CreateFileW(psobject lib, string lpFileName, int dwDesiredAccess, System.IO.FileShare dwShareMode, System.IntPtr lpSecurityAttributes,
#                       System.IO.FileMode dwCreationDisposition, int dwFlagsAndAttributes, System.IntPtr hTemplateFile)
# Name                : CreateFileW
# IsInstance          : True

$lib | Get-Member -Name CreateFileW

#    TypeName: Ctypes.Library

# Name        MemberType Definition
# ----        ---------- ----------
# CreateFileW CodeMethod static System.IntPtr CreateFileW(psobject lib, string lpFileName, int dwDesiredAccess, ...
```

As each method is defined on the library object itself, they will not appear on the output of `New-CtypesLib` even if the same dll/library was specified.

_Note: The code is shown as static with the first argument being a `PSObject`. This is just a byproduct of the `PSCodeMethod` object, it is not static and the first argument can be ignored._

# Redefining the Signature
It is currently not possible to redefine the signature on an existing method.
To use a new signature, either create a new Ctypes library object with `New-CtypesLib` and define the signature there or use the `EntryPoint()` method to define a new method for the same PInvoke function.
For example:

```powershell
$lib.Returns([IntPtr]).SetLastError().CreateFileW = [Ordered]@{
    lpFileName = $lib.MarshalAs([string], "LPWStr")
    dwDesiredAccess = [int]
    dwShareMode = [System.IO.FileShare]
    lpSecurityAttributes = [IntPtr]
    dwCreationDisposition = [System.IO.FileMode]
    dwFlagsAndAttributes = [int]
    hTemplateFile = [IntPtr]
}

$lib.SetLastError().CharSet('Unicode').EntryPoint('CreateFileW').CreateFileWithSA = [Ordered]@{
    lpFileName = $lib.MarshalAs([string], "LPWStr")
    dwDesiredAccess = [int]
    dwShareMode = [System.IO.FileShare]
    lpSecurityAttributes = [SECURITY_ATTRIBUTES]
    dwCreationDisposition = [System.IO.FileMode]
    dwFlagsAndAttributes = [int]
    hTemplateFile = [IntPtr]
}

# Calls the IntPtr overload
$lib.CreateFileW(...)

# Calls the SECURITY_ATTRIBUTES overload
$lib.CreateFileWithSA(...)
```

This creates to methods that ultimately point to `CreateFileW`; one called `CreateFileW` and the other `CreateFileWithSA`.
It is possible to now call both methods using the overloads they specified.

There can be multiple Ctypes library objects for the same DLL without them interacting with each other.
