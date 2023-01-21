. ([IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

Describe "New-CtypesLib" {
    It "Creates lib object" {
        $actual = New-CtypesLib MyLib
        $actual | Should -BeOfType ([Ctypes.Library])
        $actual.DllName | Should -Be 'MyLib'
        $actual.LastError | Should -Be 0
    }
}
