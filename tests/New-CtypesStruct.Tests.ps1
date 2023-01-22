. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "New-CtypesStruct" {
    It "Fails with begin block" {
        { ctypes_struct Test {
            begin {
                [int]$Field
            }
        } } | Should -Throw 'ctypes_struct must not contain explicit begin, process, or end blocks'
    }

    It "Fails with process block" {
        { ctypes_struct Test {
            process {
                [int]$Field
            }
        } } | Should -Throw 'ctypes_struct must not contain explicit begin, process, or end blocks'
    }

    It "Fails with begin block" {
        { ctypes_struct Test {
            end {
                [int]$Field
            }
        } } | Should -Throw 'ctypes_struct must not contain explicit begin, process, or end blocks'
    }

    It 'Fails with command field' {
        { ctypes_struct Test {
            Get-PSDrive
        }} | Should -Throw 'ctypes_struct must only contain `[type`]$FieldName lines for each struct field'
    }

    It 'Fails with pipelined expression field' {
        { ctypes_struct Test {
            [int]$Field | Write-Output
        }} | Should -Throw 'ctypes_struct must only contain `[type`]$FieldName lines for each struct field'
    }

    It 'Fails with variable assignment field' {
        { ctypes_struct Test {
            $var = 'abc'
        }} | Should -Throw 'ctypes_struct must only contain `[type`]$FieldName lines for each struct field'
    }

    It 'Fails with unknown attribute' {
        { ctypes_struct Test {
            [MyAttribute()]$var
        }} | Should -Throw 'Unknown attribute ''MyAttribute'', only MarshalAs and FieldOffset supported'
    }

    It 'Fails with array expression' {
        { ctypes_struct Test {
            [int[]]@('abc')
        }} | Should -Throw 'ctypes_struct line ''`[int`[`]`]@(''abc'')'' must be a variable expression `[type`]$FieldName'
    }

    It 'Fails with invalid UnmanagedType enum string' {
        { ctypes_struct Test {
            [MarshalAs('fake')][string]$Foo
        }} | Should -Throw 'Failed to extract MarshalAs UnmanagedType value for `[MarshalAs(''fake'')`]'
    }

    It 'Fails with invalid ArraySubType enum string' {
        { ctypes_struct Test {
            [MarshalAs('ByValArray', ArraySubType='fake', SizeConst=1)][int[]]$Foo
        }} | Should -Throw 'Failed to extract expected enum UnmanagedType value for ArraySubType'
    }

    It 'Fails with invalid MarshalAs named attribute' {
        { ctypes_struct Test {
            [MarshalAs('ByValArray', Unknown=0)][int[]]$Foo
        }} | Should -Throw 'Unsupported MarshalAs named argument ''Unknown'', expecting ArraySubType or SizeConst'
    }

    It 'Fails with no MarshalAs attribute value' {
        { ctypes_struct Test {
            [MarshalAs()][int[]]$Foo
        }} | Should -Throw 'Expecting 1 argument for MarshalAs attribute but found 0'
    }

    It 'Fails with multiple MarshalAs attribute values' {
        { ctypes_struct Test {
            [MarshalAs(1, 2)][int[]]$Foo
        }} | Should -Throw 'Expecting 1 argument for MarshalAs attribute but found 2'
    }

    It 'Fails with MarshalAs string SizeConst value' {
        { ctypes_struct Test {
            [MarshalAs('LPWStr', SizeConst='a')][int[]]$Foo
        }} | Should -Throw 'Failed to extract expected int value for SizeConst'
    }

    It 'Fails with no FieldOffset attribute value' {
        { ctypes_struct Test {
            [FieldOffset()][int[]]$Foo
        }} | Should -Throw 'Expecting 1 argument for FieldOffset attribute but found 0'
    }

    It 'Fails with multiple FieldOffset attribute values' {
        { ctypes_struct Test {
            [FieldOffset(1, 2)][int[]]$Foo
        }} | Should -Throw 'Expecting 1 argument for FieldOffset attribute but found 2'
    }

    It 'Creates struct with default (sequential) layout' {
        ctypes_struct SequentialStruct {
            [int]$Field
        }

        [SequentialStruct].IsPublic | Should -BeTrue
        [SequentialStruct].IsValueType | Should -BeTrue
        [SequentialStruct].IsLayoutSequential | Should -BeTrue
        [SequentialStruct].IsExplicitLayout | Should -BeFalse
        [SequentialStruct].IsAutoLayout | Should -BeFalse
        [SequentialStruct].StructLayoutAttribute.Value | Should -Be 'Sequential'
        [SequentialStruct].StructLayoutAttribute.Pack | Should -Be 0
        [SequentialStruct].StructLayoutAttribute.CharSet | Should -Be 'Ansi'

        [SequentialStruct].DeclaredFields.Count | Should -Be 1
        [SequentialStruct].DeclaredFields[0].Name | Should -Be 'Field'
        [SequentialStruct].DeclaredFields[0].FieldType | Should -Be ([int])
        [SequentialStruct].DeclaredFields[0].CustomAttributes.Count | Should -Be 0
    }

    It 'Creates struct with explicit layout' {
        ctypes_struct ExplicitStruct -LayoutKind Explicit {
            [FieldOffset(1)][int]$Field
        }

        [ExplicitStruct].IsPublic | Should -BeTrue
        [ExplicitStruct].IsValueType | Should -BeTrue
        [ExplicitStruct].IsLayoutSequential | Should -BeFalse
        [ExplicitStruct].IsExplicitLayout | Should -BeTrue
        [ExplicitStruct].IsAutoLayout | Should -BeFalse
        [ExplicitStruct].StructLayoutAttribute.Value | Should -Be 'Explicit'
        [ExplicitStruct].StructLayoutAttribute.Pack | Should -Be 0
        [ExplicitStruct].StructLayoutAttribute.CharSet | Should -Be 'Ansi'

        [ExplicitStruct].DeclaredFields.Count | Should -Be 1
        [ExplicitStruct].DeclaredFields[0].Name | Should -Be 'Field'
        [ExplicitStruct].DeclaredFields[0].FieldType | Should -Be ([int])
        [ExplicitStruct].DeclaredFields[0].CustomAttributes.Count | Should -Be 1
        [ExplicitStruct].DeclaredFields[0].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.FieldOffsetAttribute])
        [ExplicitStruct].DeclaredFields[0].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [ExplicitStruct].DeclaredFields[0].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([int])
        [ExplicitStruct].DeclaredFields[0].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be 1
    }

    It 'Creates struct with auto layout' {
        ctypes_struct AutoStruct -LayoutKind Auto {
            [int]$Field
        }

        [AutoStruct].IsPublic | Should -BeTrue
        [AutoStruct].IsValueType | Should -BeTrue
        [AutoStruct].IsLayoutSequential | Should -BeFalse
        [AutoStruct].IsExplicitLayout | Should -BeFalse
        [AutoStruct].IsAutoLayout | Should -BeTrue
        [AutoStruct].StructLayoutAttribute.Value | Should -Be 'Auto'
        [AutoStruct].StructLayoutAttribute.Pack | Should -Be 0
        [AutoStruct].StructLayoutAttribute.CharSet | Should -Be 'Ansi'

        [AutoStruct].DeclaredFields.Count | Should -Be 1
        [AutoStruct].DeclaredFields[0].Name | Should -Be 'Field'
        [AutoStruct].DeclaredFields[0].FieldType | Should -Be ([int])
        [AutoStruct].DeclaredFields[0].CustomAttributes.Count | Should -Be 0
    }

    It 'Creates struct with CharSet' {
        ctypes_struct CharSetUnicode -CharSet Unicode {
            [int]$Field
        }

        [CharSetUnicode].IsPublic | Should -BeTrue
        [CharSetUnicode].IsValueType | Should -BeTrue
        [CharSetUnicode].IsLayoutSequential | Should -BeTrue
        [CharSetUnicode].IsExplicitLayout | Should -BeFalse
        [CharSetUnicode].IsAutoLayout | Should -BeFalse
        [CharSetUnicode].StructLayoutAttribute.Value | Should -Be 'Sequential'
        [CharSetUnicode].StructLayoutAttribute.Pack | Should -Be 0
        [CharSetUnicode].StructLayoutAttribute.CharSet | Should -Be 'Unicode'

        [CharSetUnicode].DeclaredFields.Count | Should -Be 1
        [CharSetUnicode].DeclaredFields[0].Name | Should -Be 'Field'
        [CharSetUnicode].DeclaredFields[0].FieldType | Should -Be ([int])
        [CharSetUnicode].DeclaredFields[0].CustomAttributes.Count | Should -Be 0
    }

    It 'Creates struct with Pack' {
        ctypes_struct PackStruct -Pack 4 {
            [int]$Field
        }

        [PackStruct].IsPublic | Should -BeTrue
        [PackStruct].IsValueType | Should -BeTrue
        [PackStruct].IsLayoutSequential | Should -BeTrue
        [PackStruct].IsExplicitLayout | Should -BeFalse
        [PackStruct].IsAutoLayout | Should -BeFalse
        [PackStruct].StructLayoutAttribute.Value | Should -Be 'Sequential'
        [PackStruct].StructLayoutAttribute.Pack | Should -Be 4
        [PackStruct].StructLayoutAttribute.CharSet | Should -Be 'Ansi'

        [PackStruct].DeclaredFields.Count | Should -Be 1
        [PackStruct].DeclaredFields[0].Name | Should -Be 'Field'
        [PackStruct].DeclaredFields[0].FieldType | Should -Be ([int])
        [PackStruct].DeclaredFields[0].CustomAttributes.Count | Should -Be 0
    }

    It 'Creates struct with complex fields' {
        ctypes_struct Complex {
            $Field1
            [string]$Field2
            [FieldOffset(1)]$Field3
            [fieldoffset(2)][byte]$Field4
            [MarshalAs('LPWStr')]$Field5
            [marshalas(128)][int]$Field6
            [MarshalAs('ByValArray', arraysubtype=1, sizeconst=1)][int[]]$Field7
            [MarshalAs('ByValArray', ArraySubType='LPWStr', SizeConst=2)][string[]]$Field8
            [FieldOffset(10)][MarshalAs('LPWStr')][string]$Field9
        }

        [Complex].IsPublic | Should -BeTrue
        [Complex].IsValueType | Should -BeTrue
        [Complex].IsLayoutSequential | Should -BeTrue
        [Complex].IsExplicitLayout | Should -BeFalse
        [Complex].IsAutoLayout | Should -BeFalse
        [Complex].StructLayoutAttribute.Value | Should -Be 'Sequential'
        [Complex].StructLayoutAttribute.Pack | Should -Be 0
        [Complex].StructLayoutAttribute.CharSet | Should -Be 'Ansi'

        [Complex].DeclaredFields.Count | Should -Be 9

        [Complex].DeclaredFields[0].Name | Should -Be 'Field1'
        [Complex].DeclaredFields[0].FieldType | Should -Be ([IntPtr])
        [Complex].DeclaredFields[0].CustomAttributes.Count | Should -Be 0

        [Complex].DeclaredFields[1].Name | Should -Be 'Field2'
        [Complex].DeclaredFields[1].FieldType | Should -Be ([string])
        [Complex].DeclaredFields[1].CustomAttributes.Count | Should -Be 0

        [Complex].DeclaredFields[2].Name | Should -Be 'Field3'
        [Complex].DeclaredFields[2].FieldType | Should -Be ([IntPtr])
        [Complex].DeclaredFields[2].CustomAttributes.Count | Should -Be 1
        [Complex].DeclaredFields[2].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.FieldOffsetAttribute])
        [Complex].DeclaredFields[2].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[2].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([int])
        [Complex].DeclaredFields[2].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be 1

        [Complex].DeclaredFields[3].Name | Should -Be 'Field4'
        [Complex].DeclaredFields[3].FieldType | Should -Be ([byte])
        [Complex].DeclaredFields[3].CustomAttributes.Count | Should -Be 1
        [Complex].DeclaredFields[3].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.FieldOffsetAttribute])
        [Complex].DeclaredFields[3].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[3].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([int])
        [Complex].DeclaredFields[3].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be 2

        [Complex].DeclaredFields[4].Name | Should -Be 'Field5'
        [Complex].DeclaredFields[4].FieldType | Should -Be ([IntPtr])
        [Complex].DeclaredFields[4].CustomAttributes.Count | Should -Be 1
        [Complex].DeclaredFields[4].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
        [Complex].DeclaredFields[4].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[4].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        [Complex].DeclaredFields[4].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::LPWStr)

        [Complex].DeclaredFields[5].Name | Should -Be 'Field6'
        [Complex].DeclaredFields[5].FieldType | Should -Be ([int])
        [Complex].DeclaredFields[5].CustomAttributes.Count | Should -Be 1
        [Complex].DeclaredFields[5].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
        [Complex].DeclaredFields[5].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[5].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        [Complex].DeclaredFields[5].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be 128

        [Complex].DeclaredFields[6].Name | Should -Be 'Field7'
        [Complex].DeclaredFields[6].FieldType | Should -Be ([int[]])
        [Complex].DeclaredFields[6].CustomAttributes.Count | Should -Be 1
        [Complex].DeclaredFields[6].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
        [Complex].DeclaredFields[6].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[6].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        [Complex].DeclaredFields[6].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::ByValArray)
        $arg = [Complex].DeclaredFields[6].CustomAttributes[0].NamedArguments | Where-Object MemberName -eq ArraySubType
        $arg.TypedValue.ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        $arg.TypedValue.Value | Should -Be 1
        $arg = [Complex].DeclaredFields[6].CustomAttributes[0].NamedArguments | Where-Object MemberName -eq SizeConst
        $arg.TypedValue.ArgumentType | Should -Be ([int])
        $arg.TypedValue.Value | Should -Be 1

        [Complex].DeclaredFields[7].Name | Should -Be 'Field8'
        [Complex].DeclaredFields[7].FieldType | Should -Be ([string[]])
        [Complex].DeclaredFields[7].CustomAttributes.Count | Should -Be 1
        [Complex].DeclaredFields[7].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
        [Complex].DeclaredFields[7].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[7].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        [Complex].DeclaredFields[7].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::ByValArray)
        $arg = [Complex].DeclaredFields[7].CustomAttributes[0].NamedArguments | Where-Object MemberName -eq ArraySubType
        $arg.TypedValue.ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        $arg.TypedValue.Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::LPWStr)
        $arg = [Complex].DeclaredFields[7].CustomAttributes[0].NamedArguments | Where-Object MemberName -eq SizeConst
        $arg.TypedValue.ArgumentType | Should -Be ([int])
        $arg.TypedValue.Value | Should -Be 2

        [Complex].DeclaredFields[8].Name | Should -Be 'Field9'
        [Complex].DeclaredFields[8].FieldType | Should -Be ([string])
        [Complex].DeclaredFields[8].CustomAttributes.Count | Should -Be 2
        [Complex].DeclaredFields[8].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
        [Complex].DeclaredFields[8].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[8].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
        [Complex].DeclaredFields[8].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::LPWStr)
        [Complex].DeclaredFields[8].CustomAttributes[1].AttributeType | Should -Be ([System.Runtime.InteropServices.FieldOffsetAttribute])
        [Complex].DeclaredFields[8].CustomAttributes[1].ConstructorArguments.Count | Should -Be 1
        [Complex].DeclaredFields[8].CustomAttributes[1].ConstructorArguments[0].ArgumentType | Should -Be ([int])
        [Complex].DeclaredFields[8].CustomAttributes[1].ConstructorArguments[0].Value | Should -Be 10
    }
}
