---
external help file: Ctypes.dll-Help.xml
Module Name: Ctypes
online version: https://www.github.com/jborean93/PowerShell-Ctypes/blob/main/docs/en-US/New-CtypesStruct.md
schema: 2.0.0
---

# New-CtypesStruct

## SYNOPSIS
Dynamically define a new struct type in PowerShell.

## SYNTAX

```
New-CtypesStruct [-Name] <String> [-Body] <ScriptBlock> [-LayoutKind <LayoutKind>] [-CharSet <CharSet>]
 [-Pack <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Dynamically define a struct ValueType in PowerShell.
The struct is defined in a dynamic assembly when created through reflection.

## EXAMPLES

### Example 1 - Create SECURITY_ATTRIBUTES struct
```powershell
PS C:\> ctypes_struct SECURITY_ATTRIBUTES {
    [int]$Length
    [IntPtr]$SecurityDescriptor
    [bool]$InheritHandle
}
PS C:\> $sa = [SECURITY_ATTRIBUTES]::new()
PS C:\> $sa.Length = [System.Runtime.InteropServices.Marshal]::SizeOF($sa)
PS C:\> $sa.InheritHandle = $true
```

Defines the [SECURITY_ATTRIBUTES](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/aa379560(v=vs.85)) struct.
Each field is defined on a new line with the type and field name.

### Example 2 - Create struct with marshaling field
```powershell
PS C:\> ctypes_struct STARTUPINFOW -CharSet Unicode {
    [int]$CB
    [MarshalAs('LPWStr')][string]$Reserved
    [MarshalAs('LPWStr')][string]$Desktop
    [MarshalAs('LPWStr')][IntPtr]$Title
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
```

Defines the [STARTUPINFOW](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow) struct with the string fields with explicit MarshalAs attributes.
The `MarshalAs` attribute accepts a value from [UnmanagedType](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.unmanagedtype?view=net-7.0) as well as values for `SizeConst` and `ArraySubType`.

### Example 3 - Create struct with explicit layout
```powershell
PS C:\> ctypes_struct SYSTEM_INFO -LayoutKind Explicit {
    [FieldOffset(0)][int]$OemId
    [FieldOffset(8)][int]$PageSize
    [FieldOffset(16)][int]$ActiveProcessorMask
    [FieldOffset(24)][int]$NumberOfProcessors
    [FieldOffset(32)][int]$ProcessorType

}
```

Defines a struct with the `Explicit` layout and field offsets for each field inside the struct.

## PARAMETERS

### -Body
The struct fields with each line defining the field information.

```yaml
Type: ScriptBlock
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CharSet
Set the `CharSet` on the struct, this corresponds to the `[StructLayout(..., CharSet = CharSet.Unicode)]` attribute.

```yaml
Type: CharSet
Parameter Sets: (All)
Aliases:
Accepted values: None, Ansi, Unicode, Auto

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LayoutKind
Set the `LayoutKind` on the struct, this corresponds to the `[StructLayout(LayoutKind.Sequential)]` attribute and defaults to `Sequential`.

```yaml
Type: LayoutKind
Parameter Sets: (All)
Aliases:
Accepted values: Sequential, Explicit, Auto

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
The name of the struct to define.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Pack
Set the `Pack` on the struct, this corresponds to the `[StructLayout(..., Pack = 0)]` attribute.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
This cmdlet does not accept pipeline input.

## OUTPUTS

### System.Object
This cmdlet does not output any object.

## NOTES
Defining a struct with the same name as a previous one will overwrite the old type.

## RELATED LINKS
