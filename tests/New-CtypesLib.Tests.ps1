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

        It "Creates lib object with path" {
            $path = if ($PSVersionTable.PSVersion -lt '6.0' -or $IsWindows) {
                'C:\Windows\System32\test.dll'
            }
            else {
                '/usr/test/bin/libc.so'
            }
            $actual = New-CtypesLib $path
            $actual | Should -BeOfType ([Ctypes.Library])
            $actual.DllName | Should -Be $path
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

        It "Defines function with custom enum" -Skip:($PSVersionTable.PSVersion -lt '6.0') {
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

        It "Defined function with custom struct and enum" -Skip:($PSVersionTable.PSVersion -lt '6.0') {
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

        It "defines function with callback" {
            $lib = New-CtypesLib myLib
            $lib.MyFunc = (
                {
                    param()
                },
                {
                    [OutputType([bool])]
                    [System.Runtime.InteropServices.MarshalAs([System.Runtime.InteropServices.UnmanagedType]::U1)]
                    param ($Test)
                },
                {
                    [OutputType([IntPtr])]
                    param (
                        [System.Runtime.InteropServices.MarshalAs([System.Runtime.InteropServices.UnmanagedType]::LPWStr)]
                        [String]$Param1,

                        [IntPtr]$Param2
                    )
                }
            )

            $actual = $lib.MyFunc
            $actual | Should -BeOfType ([System.Management.Automation.PSCodeMethod])
            $actual.CodeReference.Name | Should -Be MyFunc
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 4
            $params[0].Name | Should -Be lib
            $params[0].ParameterType | Should -Be ([PSObject])

            $params[1].Name | Should -Be arg1
            $params[1].ParameterType.IsSubclassOf([System.MulticastDelegate]) | Should -BeTrue
            $params[1].ParameterType.FullName | Should -Be "MyFunc_arg1_Delegate"

            $deleg = $params[1].ParameterType.DeclaredMethods[0]
            $deleg.Name | Should -Be "Invoke"
            $deleg.ReturnType | Should -Be ([void])
            $deleg.ReturnTypeCustomAttributes.CustomAttributes.Count | Should -Be 0
            $delegParams = $deleg.GetParameters()
            $delegParams.Count | Should -Be 0

            $params[2].Name | Should -Be arg2
            $params[2].ParameterType.IsSubclassOf([System.MulticastDelegate]) | Should -BeTrue
            $params[2].ParameterType.FullName | Should -Be "MyFunc_arg2_Delegate"

            $deleg = $params[2].ParameterType.DeclaredMethods[0]
            $deleg.Name | Should -Be "Invoke"
            $deleg.ReturnType | Should -Be ([bool])
            $deleg.ReturnTypeCustomAttributes.CustomAttributes.Count | Should -Be 1
            $deleg.ReturnTypeCustomAttributes.CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
            $deleg.ReturnTypeCustomAttributes.CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
            $deleg.ReturnTypeCustomAttributes.CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
            $deleg.ReturnTypeCustomAttributes.CustomAttributes[0].ConstructorArguments[0].Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::U1)

            $delegParams = $deleg.GetParameters()
            $delegParams.Count | Should -Be 1
            $delegParams[0].Name | Should -Be "Test"
            $delegParams[0].ParameterType | Should -Be ([IntPtr])

            $params[3].Name | Should -Be arg3
            $params[3].ParameterType.IsSubclassOf([System.MulticastDelegate]) | Should -BeTrue
            $params[3].ParameterType.FullName | Should -Be "MyFunc_arg3_Delegate"

            $deleg = $params[3].ParameterType.DeclaredMethods[0]
            $deleg.Name | Should -Be "Invoke"
            $deleg.ReturnType | Should -Be ([IntPtr])
            $deleg.ReturnTypeCustomAttributes.CustomAttributes.Count | Should -Be 0
            $delegParams = $deleg.GetParameters()
            $delegParams.Count | Should -Be 2
            $delegParams[0].Name | Should -Be Param1
            $delegParams[0].ParameterType | Should -Be ([String])
            $delegParams[0].CustomAttributes.Count | Should -Be 1
            $delegParams[0].CustomAttributes[0].AttributeType | Should -Be ([System.Runtime.InteropServices.MarshalAsAttribute])
            $delegParams[0].CustomAttributes[0].ConstructorArguments.Count | Should -Be 1
            $delegParams[0].CustomAttributes[0].ConstructorArguments[0].ArgumentType | Should -Be ([System.Runtime.InteropServices.UnmanagedType])
            $delegParams[0].CustomAttributes[0].ConstructorArguments[0].Value | Should -Be ([System.Runtime.InteropServices.UnmanagedType]::LPWStr)
            $delegParams[1].Name | Should -Be Param2
            $delegParams[1].ParameterType | Should -Be ([IntPtr])
        }
    }

    Context "Windows APIs" -Skip:(-not $IsWindows) {
        It "Uses API that returns a pointer" {
            $lib = New-CtypesLib Kernel32.dll
            $res = $lib.Returns([IntPtr]).GetCurrentProcess()
            $res | Should -BeOfType ([IntPtr])
            $res | Should -Be ([IntPtr]-1)

            $lib | Get-Member -Name GetCurrentProcess | Should -Not -BeNullOrEmpty
        }

        It "Loads lib using full path" {
            $lib = New-CtypesLib "$env:SystemRoot\System32\Kernel32.dll"
            $res = $lib.Returns([IntPtr]).GetCurrentProcess()
            $res | Should -BeOfType ([IntPtr])
            $res | Should -Be ([IntPtr]-1)

            $lib | Get-Member -Name GetCurrentProcess | Should -Not -BeNullOrEmpty
        }

        It "Uses generics to specify return type" -Skip:($PSVersionTable.PSVersion -lt '7.3') {
            # Needs to be a string so that the test file can be parsed by older pwsh version
            $code = @'
            $lib = New-CtypesLib Kernel32.dll
            $res = $lib.GetCurrentProcess[IntPtr]()
            $res | Should -BeOfType ([IntPtr])
            $res | Should -Be ([IntPtr]-1)

            $lib | Get-Member -Name GetCurrentProcess | Should -Not -BeNullOrEmpty
'@

            & ([ScriptBlock]::Create($code))
        }

        It "Nulls out output" {
            $lib = New-CtypesLib Kernel32.dll
            $res = $lib.Returns([void]).GetCurrentProcess()
            $res | Should -BeNullOrEmpty
        }

        It "Nulls out output with generics" -Skip:($PSVersionTable.PSVersion -lt '7.3') {
            # Needs to be a string so that the test file can be parsed by older pwsh version
            $code = @'
            $lib = New-CtypesLib Kernel32.dll
            $res = $lib.GetCurrentProcess[void]()
            $res | Should -BeNullOrEmpty
'@

            & ([ScriptBlock]::Create($code))
        }

        It "Gets last error code on failure" {
            $lib = New-CtypesLib Kernel32.dll

            $procHandle = $lib.Returns([IntPtr]).SetLastError().OpenProcess(
                0x400, # PROCESS_QUERY_INFORMATION
                $false,
                1)
            $procHandle | Should -Be ([IntPtr]::Zero)
            $lib.LastError | Should -Be 0x00000057  # ERROR_INVALID_PARAMETER

            if ($PSVersionTable.PSVersion -ge '6.0') {
                # This test won't work on dotnet framework as it internally
                # only updates the GetLastWin32Error() value on a failure.
                $procHandle = $lib.OpenProcess(
                    0x400,
                    $false,
                    $pid)
                $procHandle | Should -Not -Be ([IntPtr]::Zero)
                try {
                    $lib.LastError | Should -Be 0
                }
                finally {
                    $lib.Returns([void]).CloseHandle($procHandle)
                }
            }
        }

        It "Uses complex argument" {
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

            $procSa = [SECURITY_ATTRIBUTES]@{
                Length = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][SECURITY_ATTRIBUTES])
                InheritHandle = $true
            }
            $si = [STARTUPINFOW]@{
                CB = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][STARTUPINFOW])
                Flags = 0x00000001  # STARTF_USESHOWWINDOW
                ShowWindow = 0  # SW_HIDE
            }
            $pi = [PROCESS_INFORMATION]::new()

            $kernel32 = New-CtypesLib Kernel32.dll

            $commandLine = [System.Text.StringBuilder]::new("powershell.exe -Command 'hi'")
            $res = $kernel32.Returns([bool]).SetLastError().CharSet('Unicode').CreateProcessW(
                $kernel32.MarshalAs("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe", 'LPWStr'),
                $commandLine,
                [ref]$procSa,
                $null,
                $false,
                # Need to cast for WinPS
                [int][ProcessCreationFlags]'CREATE_NEW_CONSOLE, CREATE_UNICODE_ENVIRONMENT',
                [IntPtr]::Zero,
                "C:\Windows",
                [ref]$si,
                [ref]$pi
            )
            if (-not $res) {
                throw [System.ComponentModel.Win32Exception]$kernel32.LastError
            }

            try {
                $pi.Pid | Should -Not -Be 0
                $pi.Thread | Should -Not -Be 0

                $handleFlags = 0
                $res = $kernel32.Returns([bool]).GetHandleInformation($pi.Process, [ref]$handleFlags)
                if (-not $res) {
                    throw [System.ComponentModel.Win32Exception]$kernel32.LastError
                }
                $handleFlags | Should -Be 1  # HANDLE_FLAG_INHERIT

                $res = $kernel32.Returns([bool]).GetHandleInformation($pi.Thread, [ref]$handleFlags)
                if (-not $res) {
                    throw [System.ComponentModel.Win32Exception]$kernel32.LastError
                }
                $handleFlags | Should -Be 0  # Not inherited
            }
            finally {
                $kernel32.Returns([void]).CloseHandle($pi.Process)
                $kernel32.CloseHandle($pi.Thread)
            }
        }

        It "Uses delegate argument" {
            $crypt = New-CtypesLib Crypt32.dll

            $stores = [System.Collections.Generic.List[string]]::new()

            $storeHandle = [System.Runtime.InteropServices.GCHandle]::Alloc($stores)
            $res = $crypt.Returns([bool]).SetLastError().CertEnumSystemStoreLocation(
                0,
                [System.Runtime.InteropServices.GCHandle]::ToIntPtr($storeHandle),
                {
                    [OutputType([bool])]
                    param (
                        [System.Runtime.InteropServices.MarshalAs([System.Runtime.InteropServices.UnmanagedType]::LPWStr)]
                        [string]$StoreLocation,
                        [int]$Flags,
                        [IntPtr]$Reserved,
                        [IntPtr]$Arg
                    )

                    $myListPtr = [System.Runtime.InteropServices.GCHandle]::FromIntPtr($Arg)
                    $myList = [System.Collections.Generic.List[String]]($myListPtr.Target)

                    $myList.Add($StoreLocation)

                    return $true
                })
            $storeHandle.Free()

            if (-not $res) {
                throw [System.ComponentModel.Win32Exception]$crypt.LastError
            }

            $stores.Count | Should -BeGreaterThan 0
        }

        It "Uses predefined delegate argument" {
            $crypt = New-CtypesLib Crypt32.dll

            $crypt.Returns([bool]).SetLastError().CertEnumSystemStoreLocation = [Ordered]@{
                Flags = [int]
                Arg = [IntPtr]
                Callback = {
                    [OutputType([bool])]
                    param (
                        [System.Runtime.InteropServices.MarshalAs([System.Runtime.InteropServices.UnmanagedType]::LPWStr)]
                        [string]$StoreLocation,
                        [int]$Flags,
                        [IntPtr]$Reserved,
                        [IntPtr]$Arg
                    )

                    # Any code here will be ignored, this is only to dynamically create the delegate.
                }
            }

            $stores = [System.Collections.Generic.List[string]]@()
            $res = $crypt.CertEnumSystemStoreLocation(0, $null, {
                    $stores.Add($args[0])

                    $true
                })
            if (-not $res) {
                throw [System.ComponentModel.Win32Exception]$crypt.LastError
            }

            $stores.Count | Should -BeGreaterThan 0
        }
    }

    Context "Linux APIs" -Skip:(-not $IsLinux) {
        It "Uses API that returns a pointer" {
            $lib = New-CtypesLib libc

            $res = $lib.Returns([IntPtr]).get_current_dir_name()
            try {
                $res | Should -BeOfType ([IntPtr])
                $cwd = [System.Runtime.InteropServices.Marshal]::PtrToStringUTF8($res)
                $cwd | Should -Be ([System.Environment]::CurrentDirectory)

                $lib | Get-Member -Name get_current_dir_name | Should -Not -BeNullOrEmpty
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

                $lib | Get-Member -Name get_current_dir_name | Should -Not -BeNullOrEmpty
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
