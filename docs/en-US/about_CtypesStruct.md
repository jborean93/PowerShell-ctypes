# Ctypes Structs
## about_CtypesStruct

# SHORT DESCRIPTION
It is very common for a C based API to use structs as arguments when dealing with complex data but there is no easy way to define a custom struct in PowerShell without restoring to `Add-Type`.
This modules provides a helper function to define these structs for you.

# LONG DESCRIPTION
A struct is considered a value type in C# and unlike reference types are passed by copying the actual value rather than by pointer.
