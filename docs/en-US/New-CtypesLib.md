---
external help file: Ctypes.dll-Help.xml
Module Name: Ctypes
online version: https://www.github.com/jborean93/PowerShell-ctypes/blob/main/docs/en-US/New-CtypesLib.md
schema: 2.0.0
---

# New-CtypesLib

## SYNOPSIS
Create an object that represents a local library to call PInvoke methods on.

## SYNTAX

```
New-CtypesLib [-Name] <String[]> [<CommonParameters>]
```

## DESCRIPTION
Creates an object that can be used to invoke a native method in a native library.
The returned object is a dynamic object that allows the caller to invoke any exported function in the native library.
Simply invoke the method by name and provide the required arguments.
See [about_CtypesInterface](./about_CtypesInterface.md) for more informatoin.

## EXAMPLES

### Example 1 - Create object to call Kernel32 OpenProcess
```powershell
PS C:\> $k32 = New-CtypesLib kernel32.dll
PS C:\> $k32.Returns([IntPtr]).SetLastError().OpenProcess(0x400, $false, $processId)
```

Creates an object that exposes the functions in `kernel32.dll`.
It then calls [OpenProcess](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocess) that is exported in that library.

## PARAMETERS

### -Name
The native library to interact with.
On Windows this is typically a `.dll`, on Linux is `.so`, and on macOS is `.dylib`.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]
The library name can be piped into the cmdlet.

## OUTPUTS

### Ctypes.Library
The ctypes library object that was created. This is a dynamic object where new PInvoke methods can be called directly.

## NOTES

## RELATED LINKS
