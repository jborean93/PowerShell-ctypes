using System;
using System.ComponentModel;
using System.Dynamic;
using System.IO;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

namespace Ctypes;

public sealed class Library : IDynamicMetaObjectProvider
{
    internal const string MARSHAL_AS_NOTE_NAME = "_CtypesMarshalAs";

    private readonly AssemblyBuilder _assembly;
    internal readonly ModuleBuilder _builder;
    internal readonly MetaObject _metaObj;

    internal CallingConvention? _callingConvention = null;
    internal CharSet? _charSet = null;
    internal string? _entryPoint = null;
    internal Type? _returnType = null;
    internal bool? _setLastError = null;

    public int LastError { get; internal set; } = 0;
    public string LastErrorMessage => new Win32Exception(LastError).Message;

    public string DllName { get; }

    public Library(string dllName)
    {
        string assemblyName = $"Ctypes.PInvoke.{Path.GetFileNameWithoutExtension(dllName)}";

        // Dotnet Framework cannot call PInvoke methods in a collectable
        // assembly so use Run there.
        _assembly = AssemblyBuilder.DefineDynamicAssembly(
            new(assemblyName),
#if NET6_0_OR_GREATER
            AssemblyBuilderAccess.RunAndCollect);
#else
            AssemblyBuilderAccess.Run);
#endif
        CustomAttributeBuilder ignoresAccessChecksTo = new(
            ReflectionInfo.IgnoreAccessChecksCtor,
            new object[] { typeof(Library).Assembly.GetName().Name! }
        );
        _assembly.SetCustomAttribute(ignoresAccessChecksTo);

        _builder = _assembly.DefineDynamicModule(assemblyName);
        _metaObj = new(this);

        DllName = dllName;
    }

    public Library CallingConvention(CallingConvention? value)
    {
        _callingConvention = value;
        return this;
    }

    public Library EntryPoint(string value)
    {
        _entryPoint = value;
        return this;
    }

    public Library Returns(Type? type)
    {
        _returnType = type;
        return this;
    }

    public Library SetLastError() => SetLastError(true);

    public Library SetLastError(bool? value)
    {
        _setLastError = value;
        return this;
    }

    public Library CharSet(CharSet? value)
    {
        _charSet = value;
        return this;
    }

    public PSObject? MarshalAs(object? value, UnmanagedType attr)
    {
        MarshalAsAttribute marshalAs = new(attr);
        return MarshalAs(value, marshalAs);
    }

    public PSObject? MarshalAs(object? value, MarshalAsAttribute attr)
    {
        if (value == null)
        {
            return null;
        }

        PSObject valueObj = PSObject.AsPSObject(value);
        PSNoteProperty marshalAsInfo = new(MARSHAL_AS_NOTE_NAME, attr);
        valueObj.Properties.Add(marshalAsInfo);

        return valueObj;
    }

    public ErrorRecord GetLastErrorRecord(
        string errorId)
    {
        ErrorRecord err = new(
            new Win32Exception(LastError),
            errorId,
            ErrorCategory.InvalidResult,
            LastError);
        err.ErrorDetails = new(string.Format(
            "{0} (0x{1:X8})", err.Exception.Message, LastError));

        return err;
    }

    public void ThrowLastErrorException()
    {
        throw new Win32Exception(LastError);
    }

    public DynamicMetaObject GetMetaObject(Expression parameter)
    {
        return new LibraryMetaObject(parameter, this, _metaObj,
            o => Expression.Field(o, nameof(_metaObj)));
    }
}
