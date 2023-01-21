# Ctypes

[![Test workflow](https://github.com/jborean93/PowerShell-ctypes/workflows/Test%20Ctypes/badge.svg)](https://github.com/jborean93/PowerShell-ctypes/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/jborean93/PowerShell-Ctypes/branch/main/graph/badge.svg?token=b51IOhpLfQ)](https://codecov.io/gh/jborean93/PowerShell-Ctypes)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/Ctypes.svg)](https://www.powershellgallery.com/packages/Ctypes)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/jborean93/PowerShell-ctypes/blob/main/LICENSE)

Provides a unique way to call native APIs in PInvoke in PowerShell.
It is modelled after the Python [ctypes library](https://docs.python.org/3/library/ctypes.html).

See [ctypes index](docs/en-US/Ctypes.md) for more details.

## Examples

Testing

## Requirements

These cmdlets have the following requirements

* PowerShell v5.1 or newer

## Installing

The easiest way to install this module is through [PowerShellGet](https://docs.microsoft.com/en-us/powershell/gallery/overview).

You can install this module by running;

```powershell
# Install for only the current user
Install-Module -Name Ctypes -Scope CurrentUser

# Install for all users
Install-Module -Name Ctypes -Scope AllUsers
```

## Contributing

Contributing is quite easy, fork this repo and submit a pull request with the changes.
To build this module run `.\build.ps1 -Task Build` in PowerShell.
To test a build run `.\build.ps1 -Task Test` in PowerShell.
This script will ensure all dependencies are installed before running the test suite.
