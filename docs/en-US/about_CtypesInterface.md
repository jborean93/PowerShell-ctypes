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

_Note: The return type was defined using the new generics syntax added in PowerShell 7.3. Older PowerShell versions should use the `.Returning([Type])` method instead.

Once called, the signature for this function is stored on the `$kernel32` object and can be viewed with `Get-Member`.
Any other functions called will also appear here.

To predefine the function before it is called, simply assign an array or ordered dictionary with the parameter types needed.
For example using an array looks like

```powershell
$kernel32.Returning([IntPtr]).OpenProcess = @(
    [int],
    [bool],
    [int]
)
```

An ordered dictionary can also be used to give a label to the arguments:

```powershell
$kernel32.Returning([IntPtr]).OpenProcess = [Ordered]@{
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

Predefining the argument types is useful because we can take advantage of PowerShell's casting behaviour to ensure the correct type is used rather than what is the value is when called.
For example, using an explicit enum type allows the caller to use the enum string name rather than the enum or integer value itself.

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
$advapi32.Returning([bool]).OpenProcessToken = [Ordered]@{
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

# MarshalAs Attributes

# Viewing Existing Definitions

# Redefining the Signature
It is currently not possible to redefine the signature on an existing method.
To use a new signature, create a new Ctypes library object with `New-CtypesLib` and define the signature there.
There can be multiple Ctypes library objects for the same DLL without them interacting with each other.
