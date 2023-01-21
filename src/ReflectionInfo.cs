using System;
using System.Dynamic;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Ctypes;

internal static class ReflectionInfo
{
    private static bool _triedBinderGenerics = false;
    private static FieldInfo? _invocationConstraintsField;
    private static PropertyInfo? _genericTypeParametersProperty;

    public static ConstructorInfo DllImportCallingCtor = typeof(DllImportAttribute)
        .GetConstructor(new[] { typeof(string) })!;

    public static ConstructorInfo IgnoreAccessChecksCtor =
        typeof(System.Runtime.CompilerServices.IgnoresAccessChecksToAttribute)
        .GetConstructor(new Type[] { typeof(string) })!;

    public static ConstructorInfo MarshalAsCtor = typeof(MarshalAsAttribute)
        .GetConstructor(new[] { typeof(UnmanagedType) })!;

    public static ConstructorInfo FieldOffsetCtor = typeof(FieldOffsetAttribute)
        .GetConstructor(new[] { typeof(int) })!;

    public static ConstructorInfo StructLayoutCtor = typeof(StructLayoutAttribute)
        .GetConstructor(new[] { typeof(LayoutKind) })!;

    public static FieldInfo DllImportCallingConventionField = typeof(DllImportAttribute)
        .GetField("CallingConvention")!;

    public static FieldInfo DllImportCharSetField = typeof(DllImportAttribute)
        .GetField("CharSet")!;

    public static FieldInfo DllImportEntryPointField = typeof(DllImportAttribute)
        .GetField("EntryPoint")!;

    public static FieldInfo DllImportSetLastErrorField = typeof(DllImportAttribute)
        .GetField("SetLastError")!;

    public static FieldInfo MarshalAsArraySubTypeField = typeof(MarshalAsAttribute)
        .GetField("ArraySubType")!;

    public static FieldInfo MarshalAsSizeConstField = typeof(MarshalAsAttribute)
        .GetField("SizeConst")!;

    public static FieldInfo StructLayoutCharSet = typeof(StructLayoutAttribute)
        .GetField("CharSet")!;

    public static FieldInfo StructLayoutPackField = typeof(StructLayoutAttribute)
        .GetField("Pack")!;

    public static MethodInfo NullablePtrHasValueMethod = typeof(Nullable<IntPtr>)
        .GetMethod("get_HasValue", Array.Empty<Type>())!;

    public static MethodInfo NullablePtrGetValueMethod = typeof(Nullable<IntPtr>)
        .GetMethod("GetValueOrDefault", Array.Empty<Type>())!;

    public static MethodInfo MarshalGetLastWin32ErrorMethod = typeof(Marshal)
        .GetMethod("GetLastWin32Error", Array.Empty<Type>())!;

    public static MethodInfo PSObjectGetBaseObjectMethod = typeof(PSObject)
        .GetMethod("get_BaseObject", Array.Empty<Type>())!;

    public static MethodInfo LibrarySetLastErrorMethod = typeof(Library)
        .GetMethod("set_LastError", BindingFlags.Instance | BindingFlags.NonPublic, null, new[] { typeof(Int32) }, null)!;

    public static Type? GetPSBinderGenerics(InvokeMemberBinder binder)
    {
        // This only works on 7.3, only attempt this once and skip if it failed
        // to find the relevant fields that are needed.
        if (_triedBinderGenerics && _invocationConstraintsField == null && _genericTypeParametersProperty == null)
        {
            return null;
        }
        _triedBinderGenerics = true;

        if (_invocationConstraintsField == null)
        {
            _invocationConstraintsField = binder.GetType()
                .GetField("_invocationConstraints", BindingFlags.Instance | BindingFlags.NonPublic);
            if (_invocationConstraintsField == null)
            {
                return null;
            }
        }

        object? invocationConstraints = _invocationConstraintsField.GetValue(binder);
        if (invocationConstraints == null)
        {
            return null;
        }

        if (_genericTypeParametersProperty == null)
        {
            _genericTypeParametersProperty = invocationConstraints.GetType()
                .GetProperty("GenericTypeParameters", BindingFlags.Instance | BindingFlags.Public);
            if (_genericTypeParametersProperty == null)
            {
                return null;
            }
        }

        object[] genericTypeParameters = (object[]?)_genericTypeParametersProperty
            .GetValue(invocationConstraints) ?? Array.Empty<object>();
        if (genericTypeParameters.Length == 0)
        {
            return null;
        }
        else if (genericTypeParameters.Length > 1)
        {
            throw new ArgumentException($"Only 1 generic type expected in method invocation");
        }

        switch (genericTypeParameters[0])
        {
            case Type g:
                return g;

            case ITypeName g:
                return g.GetReflectionType();

            default:
                throw new ArgumentException(
                    $"Unexpected generic value type found: {genericTypeParameters[0].GetType().Name}");
        }
    }
}
