ctypes_struct SECURITY_ATTRIBUTES -LayoutKind Sequential {
    [MarshalAs('U1', SizeConst=1)]$Length
    [MarshalAs(1, SizeConst=1)][IntPtr]$SecurityDescriptor
    [MarshalAs('LPWStr', SizeConst=1)][bool]$InheritHandle
}
