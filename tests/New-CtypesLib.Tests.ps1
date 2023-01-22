. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "New-CtypesLib" {
    Context "Reflection tests" {
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
            $actual.CodeReference.Name | Should -Be 'MyFunc'
            $actual.CodeReference.ReturnType | Should -Be ([int])

            $params = $actual.CodeReference.GetParameters()
            $params.Count | Should -Be 1
            $params[0].Name | Should -Be 'lib'
            $params[0].ParameterType | Should -Be ([PSObject])

            $pinvoke = $actual.CodeReference.DeclaringType.GetMethod('ExternMyFunc',
                [System.Reflection.BindingFlags]'Static, NonPublic')
            $a = ""
        }

        It "Defines API with array" {

        }

        It "Defines API with empty ordered dict" {

        }

        It "Defines API with ordered dict" {

        }

        It "Defines API with Returns" {

        }

        It "Defines API with CharSet" {
        }

        It "Defines API with EntryPoint" {

        }

        It "Defines API with SetLastError" {

        }

        It "Defines API with CallingConvention" {

        }

        It "Defines API with MarshalAs parameter" {

        }

        It "Defines API with ref type" {

        }

        It "Defines API with null/IntPtr type" {

        }
    }

    Context "Windows APIs" -Skip:(-not $IsWindows) {

    }

    Context "Linux APIs" -Skip:(-not $IsLinux) {

    }
}
