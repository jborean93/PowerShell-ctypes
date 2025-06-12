# Changelog for Ctypes

## v0.3.0 - 2025-06-12

+ Set minimum PowerShell 7 version as 7.4
+ Added `MarshalAs` support for specifying the full `MarshalAsAttribute` value for more complex scenarios
+ Added `LastErrorMessage`, `ThrowLastErrorException()` and `GetLastErrorRecord()` as a convenient ways for getting the last native error details

## v0.2.1 - 2024-11-11

+ Fix specifying dll through full path rather than just the filename

## v0.2.0 - 2023-03-06

+ Add support for defining C callback/delegate functions using a PowerShell scriptblock

## v0.1.0 - 2023-01-23

+ Initial version of the `Ctypes` module
