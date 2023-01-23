. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "New-CtypesLib" {
    Context "Reflection tests" {
        BeforeAll {
            Function Get-Attribute {
                [OutputType([System.Attribute])]
                param (
                    [Parameter(Mandatory, ValueFromPipeline)]
                    [System.Reflection.CustomAttributeData[]]
                    $Attribute
                )

                process {
                    foreach ($a in $Attribute) {
                        $attr = $a.Constructor.Invoke([object[]]@(
                                $a.ConstructorArguments | ForEach-Object { $_.Value -as $_.ArgumentType }
                            ))
                        foreach ($f in $a.NamedArguments) {
                            if (-not $f.TypedValue.Value) {
                                continue
                            }
                            $attr.($f.MemberName) = $f.TypedValue.Value
                        }

                        $attr
                    }
                }
            }
        }

        It "Creates lib object" {
            $actual = New-CtypesLib MyLib
            $actual | Should -BeOfType ([Ctypes.Library])
            $actual.DllName | Should -Be 'MyLib'
            $actual.LastError | Should -Be 0
        }

        It "Defines API with empty array" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @()

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 0
        }

        It "Defines API with array" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @([int])

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with empty ordered dict" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = [Ordered]@{}

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 0
        }

        It "Defines API with ordered dict" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = [Ordered]@{
                MyArg1 = [int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with Returns" {
            $lib = New-CtypesLib MyLib
            $lib.Returns([bool]).MyFunc = [Ordered]@{
                MyArg1 = [int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([bool])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([bool])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with CharSet" {
            $lib = New-CtypesLib MyLib
            $lib.CharSet('Unicode').MyFunc = [Ordered]@{
                MyArg1 = [int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be Unicode
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with EntryPoint" {
            $lib = New-CtypesLib MyLib
            $lib.EntryPoint('CustomEntryPoint').MyFunc = [Ordered]@{
                MyArg1 = [int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be CustomEntryPoint
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with SetLastError" {
            $lib = New-CtypesLib MyLib
            $lib.SetLastError().MyFunc = [Ordered]@{
                MyArg1 = [int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeTrue

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with CallingConvention" {
            $lib = New-CtypesLib MyLib
            $lib.CallingConvention('Cdecl').MyFunc = [Ordered]@{
                MyArg1 = [int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([int])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Cdecl
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([int])
        }

        It "Defines API with MarshalAs parameter with array" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @(
                $lib.MarshalAs([string], 'LPWStr')
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([string])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([string])
            $ma = $params[0].CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.MarshalAsAttribute] } |
                Get-Attribute
            $ma.Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::LPWStr)
        }

        It "Defines API with MarshalAs parameter with ordered dict" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = [Ordered]@{
                MyArg1 = $lib.MarshalAs([string], 'LPWStr')
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([string])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([string])
            $ma = $params[0].CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.MarshalAsAttribute] } |
                Get-Attribute
            $ma.Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::LPWStr)
        }

        It "Defines API with ref type - array" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @(
                [ref][int]
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([int].MakeByRefType())

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([int].MakeByRefType())
        }

        It "Defines API with ref type - ordered dict" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = [ordered]@{
                MyArg = [ref][int]
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg
            $params[1].ParameterType | Should -Be ([int].MakeByRefType())

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be MyArg
            $params[0].ParameterType | Should -Be ([int].MakeByRefType())
        }

        It "Defines API with null/IntPtr type - array" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @(
                [IntPtr]
                $null
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 3
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([Nullable[IntPtr]])
            $params[2].Name | Should -Be arg2
            $params[2].ParameterType | Should -Be ([Nullable[IntPtr]])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([IntPtr])
            $params[1].Name | Should -Be arg2
            $params[1].ParameterType | Should -Be ([IntPtr])
        }

        It "Defines API with null/IntPtr type - ordered dict" {
            $lib = New-CtypesLib MyLib
            $lib.MyFunc = [ordered]@{
                MyArg1 = [IntPtr]
                MyArg2 = $null
            }

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 3
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be MyArg1
            $params[1].ParameterType | Should -Be ([Nullable[IntPtr]])
            $params[2].Name | Should -Be MyArg2
            $params[2].ParameterType | Should -Be ([Nullable[IntPtr]])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be MyArg1
            $params[0].ParameterType | Should -Be ([IntPtr])
            $params[1].Name | Should -Be MyArg2
            $params[1].ParameterType | Should -Be ([IntPtr])
        }

        It "Clears existing method attr after defining once" {
            $lib = New-CtypesLib MyLib
            $lib.Returns([IntPtr]).CallingConvention('Cdecl').CharSet('Unicode').EntryPoint('MyEP').SetLastError().MyFunc1 = @()
            $lib.MyFunc2 = @()

            $func1 = $lib.MyFunc1
            $func1 | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $func1.CodeReference.Name | Should -Be MyFunc1
            $func1.CodeReference.ReturnType | Should -Be ([IntPtr])

            $pinvoke = $func1.CodeReference.DeclaringType.GetMethod('ExternMyFunc1',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.ReturnType | Should -Be ([IntPtr])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Cdecl
            $dllImport.CharSet | Should -Be Unicode
            $dllImport.EntryPoint | Should -Be MyEP
            $dllImport.SetLastError | Should -BeTrue

            $func2 = $lib.MyFunc2
            $func2 | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $func2.CodeReference.Name | Should -Be MyFunc2
            $func2.CodeReference.ReturnType | Should -Be ([int])

            $pinvoke = $func2.CodeReference.DeclaringType.GetMethod('ExternMyFunc2',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc2
            $dllImport.SetLastError | Should -BeFalse
        }

        It "Defines function with custom struct" {
            ctypes_struct MY_STRUCT {
                [int]$Field1
                [bool]$Field2
            }

            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @(
                [MY_STRUCT]
                [ref][MY_STRUCT]
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 3
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([MY_STRUCT])
            $params[2].Name | Should -Be arg2
            $params[2].ParameterType | Should -Be ([MY_STRUCT].MakeByRefType())

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([MY_STRUCT])
            $params[1].Name | Should -Be arg2
            $params[1].ParameterType | Should -Be ([MY_STRUCT].MakeByRefType())
        }

        It "Defines function with custom enum" {
            enum MY_ENUM {
                Enum1 = 1
                Enum2 = 2
            }

            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @(
                [MY_ENUM]
                [ref][MY_ENUM]
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 3
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([MY_ENUM])
            $params[2].Name | Should -Be arg2
            $params[2].ParameterType | Should -Be ([MY_ENUM].MakeByRefType())

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([MY_ENUM])
            $params[1].Name | Should -Be arg2
            $params[1].ParameterType | Should -Be ([MY_ENUM].MakeByRefType())
        }

        It "Defined function with custom struct and enum" {
            enum MY_ENUM {
                Enum1 = 1
                Enum2 = 2
            }
            ctypes_struct MY_STRUCT {
                [MY_ENUM]$Field1
                [bool]$Field2
            }

            $lib = New-CtypesLib MyLib
            $lib.MyFunc = @(
                [MY_STRUCT]
                [ref][MY_STRUCT]
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 3
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([MY_STRUCT])
            $params[2].Name | Should -Be arg2
            $params[2].ParameterType | Should -Be ([MY_STRUCT].MakeByRefType())

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $pinvoke.Attributes | Should -Be ([System.Reflection.MethodAttributes]'PrivateScope, Private, Static, PinvokeImpl')
            $pinvoke.ReturnType | Should -Be ([int])

            $dllImport = $pinvoke.CustomAttributes |
                Where-Object { $_.AttributeType -eq [System.Runtime.InteropServices.DllImportAttribute] } |
                Get-Attribute
            $dllImport.Value | Should -Be MyLib
            $dllImport.CallingConvention | Should -Be Winapi
            $dllImport.CharSet | Should -Be None
            $dllImport.EntryPoint | Should -Be MyFunc
            $dllImport.SetLastError | Should -BeFalse

            $params = $pinvoke.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be arg1
            $params[0].ParameterType | Should -Be ([MY_STRUCT])
            $params[1].Name | Should -Be arg2
            $params[1].ParameterType | Should -Be ([MY_STRUCT].MakeByRefType())
        }
    }

    Context "Windows APIs" -Skip:(-not $IsWindows) {

    }

    Context "Linux APIs" -Skip:(-not $IsLinux) {
        It "Uses API that returns a pointer" {
            $lib = New-CtypesLib libc

            $res = $lib.Returns([IntPtr]).get_current_dir_name()
            try {
                $res | Should -BeOfType ([IntPtr])
                $cwd = [System.Runtime.InteropServices.Marshal]::PtrToStringUTF8($res)
                $cwd | Should -Be ([System.Environment]::CurrentDirectory)
            }
            finally {
                $null = $lib.free($res)
            }
        }

        It "Uses generics to specify return type" -Skip:($PSVersionTable.PSVersion -lt '7.3') {
            # Needs to be a string so that the test file can be parsed by older pwsh version
            $code = @'
            $lib = New-CtypesLib libc

            $res = $lib.get_current_dir_name[IntPtr]()
            try {
                $res | Should -BeOfType ([IntPtr])
                $cwd = [System.Runtime.InteropServices.Marshal]::PtrToStringUTF8($res)
                $cwd | Should -Be ([System.Environment]::CurrentDirectory)
            }
            finally {
                $lib.free[void]($res)
            }
'@
            & ([ScriptBlock]::Create($code))
        }

        It "Nulls out output" {
            $lib = New-CtypesLib libc

            $res = $lib.Returns([void]).free($null)
            $res | Should -BeNullOrEmpty

            $lib.free.CodeReference.ReturnType | Should -Be ([void])
            $params = $lib.free.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([Nullable[IntPtr]])
        }

        It "Nulls out output with generics" -Skip:($PSVersionTable.PSVersion -lt '7.3') {
            # Needs to be a string so that the test file can be parsed by older pwsh version
            $code = @'
            $lib = New-CtypesLib libc

            $res = $lib.free[void]($null)
            $res | Should -BeNullOrEmpty

            $lib.free.CodeReference.ReturnType | Should -Be ([void])
            $params = $lib.free.CodeReference.GetParameters()
            $params.Count | Should -Be 2
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])
            $params[1].Name | Should -Be arg1
            $params[1].ParameterType | Should -Be ([Nullable[IntPtr]])
'@

            & ([ScriptBlock]::Create($code))
        }

        It "Uses string parameter" {
            [Flags()] enum OpenFlags {
                O_RDONLY = 0x00000000
                O_WRONLY = 0x00000001
                O_RDWR = 0x00000002
                O_CREAT = 0x00000040
                O_TRUNC = 0x00000200
            }

            $lib = New-CtypesLib libc

            $filePath = "/tmp/pwsh-ctypes-$([Guid]::NewGuid())"
            $fd = $lib.open(
                $lib.MarshalAs($filePath, 'LPUTF8Str'),
                [OpenFlags]'O_CREAT, O_WRONLY, O_TRUNC',
                448  # S_IRWXU
            )
            $fd | Should -Not -Be -1

            try {
                Test-Path -Path $filePath | Should -BeTrue
            }
            finally {
                $lib.Returns([void]).close($fd)
            }
        }

        It "Gets last error code on failure" {
            $lib = New-CtypesLib libc

            $filePath = "/tmp/missing folder/pwsh-ctypes-$([Guid]::NewGuid())"
            $fd = $lib.SetLastError().open(
                $lib.MarshalAs($filePath, 'LPUTF8Str'),
                0x42,
                448  # S_IRWXU
            )
            $fd | Should -Be -1
            $lib.LastError | Should -Be 2
        }
    }
}
