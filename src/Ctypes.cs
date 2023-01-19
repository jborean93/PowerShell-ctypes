using System;
using System.Collections.Generic;
using System.Dynamic;
using System.Linq;
using System.Management.Automation;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

namespace Ctypes;

[Cmdlet(VerbsCommon.Get, "CtypesLib")]
[OutputType(typeof(Library))]
public sealed class GetCtypesLibCommand : PSCmdlet
{
    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    public string[] Name { get; set; } = Array.Empty<string>();

    protected override void ProcessRecord()
    {
        foreach (string n in Name)
        {
            WriteObject(new Library(n));
        }
    }
}

[Cmdlet(VerbsCommon.New, "CtypesStruct")]
[OutputType(typeof(Type))]
public sealed class NewCtypesStructCommand : PSCmdlet
{
    private ModuleBuilder _builder = default!;

    [Parameter(
        Mandatory = true,
        Position = 0
    )]
    public string Name { get; set; } = "";

    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true,
        ValueFromPipelineByPropertyName = true
    )]
    public PSObject[] InputObject { get; set; } = Array.Empty<PSObject>();

    [Parameter()]
    public SwitchParameter PassThru { get; set; }

    protected override void BeginProcessing()
    {
        string assemblyName = $"Ctypes.Struct.{Name}";
        AssemblyBuilder assembly = AssemblyBuilder.DefineDynamicAssembly(
            new(assemblyName),
            AssemblyBuilderAccess.Run);
        _builder = assembly.DefineDynamicModule(assemblyName);
    }

    protected override void ProcessRecord()
    {
        foreach (PSObject obj in InputObject)
        {
            TypeBuilder tb = _builder.DefineType(
                Name,
                TypeAttributes.Public | TypeAttributes.Sealed | TypeAttributes.AutoLayout,
                typeof(ValueType));

            List<FieldInfo> fields = new()
            {
            };
            List<object> fieldValues = new()
            {
            };

            CustomAttributeBuilder structLayout = new(
                typeof(StructLayoutAttribute).GetConstructor(new[] { typeof(LayoutKind) })!,
                new object[] { LayoutKind.Sequential },
                fields.ToArray(),
                fieldValues.ToArray()
            );
            tb.SetCustomAttribute(structLayout);


            foreach (PSNoteProperty prop in obj.Properties.Match("*", PSMemberTypes.NoteProperty))
            {
                tb.DefineField(prop.Name, (Type)prop.Value, FieldAttributes.Public);
            }

            Type? structType = tb.CreateType();
            if (PassThru && structType != null)
            {
                WriteObject(structType);
            }
        }
    }
}

public sealed class Library : DynamicObject
{
    internal const string MARSHAL_AS_NOTE_NAME = "_CtypesMarshalAs";

    private readonly AssemblyBuilder _assembly;
    private readonly ModuleBuilder _builder;

    private CallingConvention? _callingConvention = null;
    private CharSet? _charSet = null;
    private Type? _returnType = null;
    private bool? _setLastError = null;

    public int LastError { get; internal set; } = 0;

    public string DllName { get; }

    public Library(string dllName)
    {
        string assemblyName = $"Ctypes.PInvoke.{dllName}";
        _assembly = AssemblyBuilder.DefineDynamicAssembly(
            new(assemblyName),
            AssemblyBuilderAccess.RunAndCollect);
        CustomAttributeBuilder ignoresAccessChecksTo = new(
            ReflectionInfo.IgnoreAccessChecksCtor,
            new object[] { typeof(Library).Assembly.GetName().Name! }
        );
        _assembly.SetCustomAttribute(ignoresAccessChecksTo);

        _builder = _assembly.DefineDynamicModule(assemblyName);

        DllName = dllName;
    }

    public Library CallingConvention(CallingConvention? value)
    {
        _callingConvention = value;
        return this;
    }

    public Library Returning(Type? type)
    {
        _returnType = type;
        return this;
    }

    public Library SetLastError(bool? value)
    {
        _setLastError = value;
        return this;
    }

    public Library SetCharSet(CharSet? value)
    {
        _charSet = value;
        return this;
    }

    public PSObject? MarshalAs(object? value, UnmanagedType attr)
    {
        if (value == null)
        {
            return null;
        }

        CustomAttributeBuilder marshalAs = new(
            ReflectionInfo.MarshalAsCtor,
            new object[] { attr });

        PSObject valueObj = PSObject.AsPSObject(value);
        PSNoteProperty marshalAsInfo = new(MARSHAL_AS_NOTE_NAME, marshalAs);
        valueObj.Properties.Add(marshalAsInfo);

        return valueObj;
    }

    public override bool TryInvokeMember(InvokeMemberBinder binder, object?[]? args, out object? result)
    {
        // Called when the method specified does not exist as a member. This
        // creates a new PSCodeMethod that invokes the PInvoke method
        // requested. As pwsh ETS members are checked before dotnet, this is
        // only called the first time and subsequent calls to the same method
        // goes through the ETS member.
        ParameterInfo[] paramInformation = args
            ?.Select(a => new ParameterInfo(a))
            ?.ToArray() ?? Array.Empty<ParameterInfo>();

        MethodInfo meth = CreatePInvokeExtern(
            _builder,
            DllName,
            binder.Name,
            _returnType ?? typeof(void),
            paramInformation,
            _setLastError,
            _callingConvention,
            _charSet);
        _callingConvention = null;
        _charSet = null;
        _returnType = null;
        _setLastError = null;

        // Adds the new method to the current object's ETS members so the
        // subequent calls go through that.
        PSObject thisObj = PSObject.AsPSObject(this);
        thisObj.Members.Add(new PSCodeMethod(binder.Name, meth));

        // Still need to call it manually on the first go.
        object?[] invokeArgs = new[] { PSObject.AsPSObject(this) }
            .Concat(paramInformation.Select(p => p.Value) ?? Array.Empty<object?>())
            .ToArray();
        result = meth.Invoke(null, invokeArgs);

        // Any reference values need to be applied back to the caller.
        for (int i = 0; i < paramInformation.Length; i++)
        {
            ParameterInfo info = paramInformation[i];
            if (info.RefValue != null)
            {
                info.RefValue.Value = invokeArgs[i + 1];
            }
        }

        return true;
    }

    private static MethodInfo CreatePInvokeExtern(
        ModuleBuilder builder,
        string dllName,
        string name,
        Type returnType,
        ParameterInfo[] parameterTypes,
        bool? setLastError,
        CallingConvention? callingConvention,
        CharSet? charSet)
    {
        TypeBuilder tb = builder.DefineType(
            name,
            TypeAttributes.Sealed | TypeAttributes.NotPublic);

        List<FieldInfo> fields = new()
        {
            ReflectionInfo.DllImportEntryPointField
        };
        List<object> fieldValues = new()
        {
            name
        };

        if (callingConvention != null)
        {
            fields.Add(ReflectionInfo.DllImportCallingConventionField);
            fieldValues.Add(callingConvention);
        }

        if (charSet != null)
        {
            fields.Add(ReflectionInfo.DllImportCharSetField);
            fieldValues.Add(charSet);
        }

        if (setLastError == true)
        {
            fields.Add(ReflectionInfo.DllImportSetLastErrorField);
            fieldValues.Add(true);
        }

        CustomAttributeBuilder dllImport = new(
            ReflectionInfo.DllImportCallingCtor,
            new[] { dllName },
            fields.ToArray(),
            fieldValues.ToArray()
        );
        MethodBuilder pinvoke = tb.DefineMethod(
            $"Extern{name}",
            MethodAttributes.Private | MethodAttributes.Static,
            returnType,
            parameterTypes.Select(p => p.ParamType).ToArray());
        pinvoke.SetCustomAttribute(dllImport);

        // This defines the wrapper Method that is added to the PSCodeMethod
        // member. It is special as it adds a PSObject parameter and sets the
        // LastError code on the library instance if SetLastError was set for
        // the method.
        MethodBuilder wrapper = tb.DefineMethod(
            name,
            MethodAttributes.Public | MethodAttributes.Static,
            returnType,
            new Type[] { typeof(PSObject) }
                .Concat(parameterTypes.Select(p => p.ParamType))
                .ToArray());

        ILGenerator il = wrapper.GetILGenerator();

        wrapper.DefineParameter(1, ParameterAttributes.None, "lib");
        for (int i = 1; i <= parameterTypes.Length; i++)
        {
            ParameterInfo info = parameterTypes[i - 1];


            ParameterAttributes attr = ParameterAttributes.None;
            if (info.MarshalAs != null)
            {
                attr |= ParameterAttributes.HasFieldMarshal;
            }
            ParameterBuilder pb = pinvoke.DefineParameter(i, attr, $"arg{i}");
            if (info.MarshalAs != null)
            {
                pb.SetCustomAttribute(info.MarshalAs);
            }

            pb = wrapper.DefineParameter(i + 1, ParameterAttributes.None, $"arg{i}");

            il.Emit(OpCodes.Ldarg_S, i);
        }
        il.Emit(OpCodes.Call, pinvoke);

        if (setLastError == true)
        {
            // ((Library)lib.BaseObject).LastError = Marshal.GetLastWin32Error();
            il.Emit(OpCodes.Ldarg_0);
            il.Emit(OpCodes.Callvirt, ReflectionInfo.PSObjectGetBaseObjectMethod);
            il.Emit(OpCodes.Castclass, typeof(Library));
            il.Emit(OpCodes.Call, ReflectionInfo.MarshalGetLastWin32ErrorMethod);
            il.Emit(OpCodes.Callvirt, ReflectionInfo.LibrarySetLastErrorMethod);
        }

        il.Emit(OpCodes.Ret);

        Type pinvokeType = tb.CreateType()
            ?? throw new RuntimeException($"Unknown error creating type for {name}");

        return pinvokeType.GetMethod(wrapper.Name,
            BindingFlags.Public | BindingFlags.Static)
            ?? throw new RuntimeException($"Unknown error getting PInvoke method for {name}");
    }
}

internal sealed class ParameterInfo
{
    public object? Value { get; }
    public Type ParamType { get; }

    public CustomAttributeBuilder? MarshalAs { get; }
    public PSReference? RefValue { get; }

    public ParameterInfo(object? value)
    {
        PSObject? valuePSObj = null;

        if (value is PSObject)
        {
            valuePSObj = (PSObject)value;
            Value = valuePSObj.BaseObject;
        }
        else if (value != null)
        {
            valuePSObj = PSObject.AsPSObject(value);
            Value = value;
        }

        if (valuePSObj != null)
        {
            PSNoteProperty? marshalAsInfo = valuePSObj.Properties
                .Match(Library.MARSHAL_AS_NOTE_NAME, PSMemberTypes.NoteProperty)
                .Cast<PSNoteProperty>()
                .FirstOrDefault();

            MarshalAs = (CustomAttributeBuilder?)marshalAsInfo?.Value;
        }

        if (Value is PSReference refValue)
        {
            RefValue = refValue;
            ParamType = (refValue.Value?.GetType() ?? typeof(void)).MakeByRefType();
            Value = refValue.Value;
        }
        else
        {
            ParamType = Value?.GetType() ?? typeof(void);
            Value = Value;
        }
    }
}

internal static class ReflectionInfo
{
    public static ConstructorInfo DllImportCallingCtor = typeof(DllImportAttribute)
        .GetConstructor(new[] { typeof(string) })!;

    public static ConstructorInfo IgnoreAccessChecksCtor =
        typeof(System.Runtime.CompilerServices.IgnoresAccessChecksToAttribute)
        .GetConstructor(new Type[] { typeof(string) })!;

    public static ConstructorInfo MarshalAsCtor = typeof(MarshalAsAttribute)
        .GetConstructor(new[] { typeof(UnmanagedType) })!;

    public static FieldInfo DllImportCallingConventionField = typeof(DllImportAttribute)
        .GetField("CallingConvention")!;

    public static FieldInfo DllImportCharSetField = typeof(DllImportAttribute)
        .GetField("CharSet")!;

    public static FieldInfo DllImportEntryPointField = typeof(DllImportAttribute)
        .GetField("EntryPoint")!;

    public static FieldInfo DllImportSetLastErrorField = typeof(DllImportAttribute)
        .GetField("SetLastError")!;

    public static MethodInfo MarshalGetLastWin32ErrorMethod = typeof(Marshal)
        .GetMethod("GetLastWin32Error", Array.Empty<Type>())!;

    public static MethodInfo PSObjectGetBaseObjectMethod = typeof(PSObject)
        .GetMethod("get_BaseObject", Array.Empty<Type>())!;

    public static MethodInfo LibrarySetLastErrorMethod = typeof(Library)
        .GetMethod("set_LastError", BindingFlags.Instance | BindingFlags.NonPublic, null, new[] { typeof(Int32) }, null)!;
}
