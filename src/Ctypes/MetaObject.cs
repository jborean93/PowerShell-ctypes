using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Dynamic;
using System.Linq;
using System.Linq.Expressions;
using System.Management.Automation;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

namespace Ctypes;

internal sealed class LibraryMetaObject : DynamicMetaObject
{
    private readonly Library _library;
    private readonly MetaObject _meta;
    private readonly DynamicMetaObject _metaTarget;

    public LibraryMetaObject(Expression expression, Library value, MetaObject meta,
        Func<Expression, Expression> metaGetter)
        : base(expression, BindingRestrictions.Empty, value)
    {
        _library = value;
        _meta = meta;
        _metaTarget = meta.GetMetaObject(
            metaGetter(Expression.Convert(expression, value.GetType())));
    }

    public override DynamicMetaObject BindSetMember(SetMemberBinder binder, DynamicMetaObject value)
    {
        PSObject psObject = PSObject.AsPSObject(_library);
        if (psObject.Members.Match(binder.Name).Count == 0)
        {
            // Return the meta object so that we can then define the Pinvoke
            // method. We can't do it here because pwsh caches this result and
            // will call the meta object directly for future instances of
            // Library.
            return _metaTarget.BindSetMember(binder, value);
        }

        return base.BindSetMember(binder, value);
    }

    public override DynamicMetaObject BindInvokeMember(InvokeMemberBinder binder, DynamicMetaObject[] args)
    {
        Type? returnType = ReflectionInfo.GetPSBinderGenerics(binder);

        PSObject psObj = PSObject.AsPSObject(_library);
        if (psObj.Members.Match(binder.Name).Count == 0)
        {
            // Called when the method specified does not exist as a member. This
            // creates a new PSCodeMethod that invokes the PInvoke method
            // requested. Due to the recursive nature of the InvokeMemberBinder
            // it will call on pwsh to find the method again but now it has the
            // PSCodeMethod it will be invoked instead of this.
            TypeInformation[] paramInformation = args
                ?.Select((a, i) => MetaObject.ParseParamInfo(_library._builder, binder.Name, $"arg{i + 1}", a.Value))
                ?.ToArray() ?? Array.Empty<TypeInformation>();

            _meta.DefinePInvokeMember(
                binder.Name,
                returnType != null
                    ? MetaObject.ParseParamInfo(_library._builder, binder.Name, "", returnType, forReturn: true)
                    : null,
                paramInformation);
        }

        return base.BindInvokeMember(binder, args!);
    }
}

internal sealed class MetaObject : DynamicObject
{
    private readonly Library _library;

    public MetaObject(Library library)
    {
        _library = library;
    }

    // Used as a target for BindSetMember when a PInvoke method is being
    // defined. Without this pwsh complains that the object has no member of
    // that name.
    public override bool TrySetMember(SetMemberBinder binder, object? value)
    {
        // Define the new PInvoke member.The value must be a list or ordered dictionary.
        TypeInformation[] paramInformation;
        if (value is IList valueList)
        {
            paramInformation = GetParametersFromList(_library._builder, binder.Name, valueList);
        }
        else if (value is OrderedDictionary valueDict)
        {
            paramInformation = GetParametersFromDict(_library._builder, binder.Name, valueDict);
        }
        else
        {
            throw new ArgumentException(
                "Defining new PInvoke signature must be done with an array @() or ordered dictionary [Ordered]@{}");
        }

        DefinePInvokeMember(binder.Name, null, paramInformation);

        return true;
    }

    internal void DefinePInvokeMember(string name, TypeInformation? returnType, TypeInformation[] parameters)
    {
        MethodInfo meth = CreatePInvokeExtern(
            _library._builder,
            _library.DllName,
            name,
            _library._entryPoint,
            returnType ?? ParseParamInfo(_library._builder, name, "", _library._returnType ?? typeof(int),
                forReturn: true),
            parameters,
            _library._setLastError,
            _library._callingConvention,
            _library._charSet);
        _library._callingConvention = null;
        _library._charSet = null;
        _library._entryPoint = null;
        _library._returnType = null;
        _library._setLastError = null;

        PSObject psObj = PSObject.AsPSObject(_library);
        if (psObj.Members.Match(name, PSMemberTypes.CodeMethod).Count > 0)
        {
            psObj.Members.Remove(name);
        }
        psObj.Members.Add(new PSCodeMethod(name, meth));
    }

    private static MethodInfo CreatePInvokeExtern(
        ModuleBuilder builder,
        string dllName,
        string name,
        string? entryPoint,
        TypeInformation returnType,
        TypeInformation[] parameterTypes,
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
            entryPoint ?? name
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
            returnType.Type,
            parameterTypes.Select(p => p.Type == typeof(IntPtr?) ? typeof(IntPtr) : p.Type).ToArray());
        pinvoke.SetCustomAttribute(dllImport);

        CustomAttributeBuilder? marshalAsBuilder = returnType.CreateMarshalAsAttribute();
        if (marshalAsBuilder != null)
        {
            ParameterBuilder pb = pinvoke.DefineParameter(0, ParameterAttributes.HasFieldMarshal, "ret");
            pb.SetCustomAttribute(marshalAsBuilder);
        }

        // This defines the wrapper Method that is added to the PSCodeMethod
        // member. It is special as it adds a PSObject parameter and sets the
        // LastError code on the library instance if SetLastError was set for
        // the method.
        MethodBuilder wrapper = tb.DefineMethod(
            name,
            MethodAttributes.Public | MethodAttributes.Static,
            returnType.Type,
            new Type[] { typeof(PSObject) }
                .Concat(parameterTypes.Select(p => p.Type))
                .ToArray());

        ILGenerator il = wrapper.GetILGenerator();

        LocalBuilder? nullPtr = null;
        LocalBuilder? nullablePtr = null;

        wrapper.DefineParameter(1, ParameterAttributes.None, "lib");
        for (int i = 1; i <= parameterTypes.Length; i++)
        {
            TypeInformation info = parameterTypes[i - 1];

            ParameterAttributes attr = ParameterAttributes.None;
            if (info.MarshalAs != null)
            {
                attr |= ParameterAttributes.HasFieldMarshal;
            }
            ParameterBuilder pb = pinvoke.DefineParameter(i, attr, info.Name);

            marshalAsBuilder = info.CreateMarshalAsAttribute();
            if (marshalAsBuilder != null)
            {
                pb.SetCustomAttribute(marshalAsBuilder);
            }

            pb = wrapper.DefineParameter(i + 1, ParameterAttributes.None, info.Name);

            il.Emit(OpCodes.Ldarg_S, i);

            if (info.Type == typeof(IntPtr?))
            {
                if (nullPtr == null)
                {
                    nullPtr = il.DeclareLocal(typeof(IntPtr));
                    il.Emit(OpCodes.Ldc_I4_0);
                    il.Emit(OpCodes.Conv_I);
                    il.Emit(OpCodes.Stloc_S, nullPtr);
                }

                if (nullablePtr == null)
                {
                    nullablePtr = il.DeclareLocal(typeof(Nullable<IntPtr>));
                }

                // The following is converting a null value to IntPtr.Zero;
                // argument ?? IntPtr.Zero;

                Label hasValueLabel = il.DefineLabel();
                Label endNullable = il.DefineLabel();

                il.Emit(OpCodes.Stloc, nullablePtr);
                il.Emit(OpCodes.Ldloca_S, nullablePtr);
                il.Emit(OpCodes.Call, ReflectionInfo.NullablePtrHasValueMethod);
                il.Emit(OpCodes.Brtrue_S, hasValueLabel);

                il.Emit(OpCodes.Ldloc, nullPtr);
                il.Emit(OpCodes.Br_S, endNullable);

                il.MarkLabel(hasValueLabel);

                il.Emit(OpCodes.Ldloca_S, nullablePtr);
                il.Emit(OpCodes.Call, ReflectionInfo.NullablePtrGetValueMethod);

                il.MarkLabel(endNullable);
            }
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

    private static Type CreateDelegateType(ModuleBuilder builder, string delegateName,
        TypeInformation returnType, TypeInformation[] parameterTypes)
    {
        TypeBuilder tb = builder.DefineType(
            delegateName,
            TypeAttributes.Sealed | TypeAttributes.Public,
            typeof(MulticastDelegate));

        ConstructorBuilder ctorBulder = tb.DefineConstructor(
            MethodAttributes.RTSpecialName | MethodAttributes.HideBySig | MethodAttributes.Public,
            CallingConventions.Standard,
            new[] { typeof(object), typeof(IntPtr) });
        ctorBulder.SetImplementationFlags(MethodImplAttributes.CodeTypeMask);

        MethodBuilder mb = tb.DefineMethod(
            "Invoke",
            MethodAttributes.HideBySig | MethodAttributes.Virtual | MethodAttributes.Public,
            returnType.Type,
            parameterTypes.Select(p => p.Type).ToArray());
        mb.SetImplementationFlags(MethodImplAttributes.CodeTypeMask);

        CustomAttributeBuilder? marshalAsBuilder = returnType.CreateMarshalAsAttribute();
        if (marshalAsBuilder != null)
        {
            ParameterBuilder pb = mb.DefineParameter(0, ParameterAttributes.HasFieldMarshal, "ret");
            pb.SetCustomAttribute(marshalAsBuilder);
        }

        for (int i = 1; i <= parameterTypes.Length; i++)
        {
            TypeInformation info = parameterTypes[i - 1];

            ParameterAttributes attr = ParameterAttributes.None;
            if (info.MarshalAs != null)
            {
                attr |= ParameterAttributes.HasFieldMarshal;
            }

            ParameterBuilder pb = mb.DefineParameter(i, attr, info.Name);

            marshalAsBuilder = info.CreateMarshalAsAttribute();
            if (marshalAsBuilder != null)
            {
                pb.SetCustomAttribute(marshalAsBuilder);
            }
        }

        return tb.CreateType()
            ?? throw new RuntimeException($"Unknown error defining delegate {delegateName}");
    }

    private static TypeInformation[] GetParametersFromList(ModuleBuilder builder, string methodName, IList raw)
    {
        return raw
            .Cast<object?>()
            .Select((r, i) => ParseParamInfo(builder, methodName, $"arg{i + 1}", r))
            .ToArray();
    }

    private static TypeInformation[] GetParametersFromDict(ModuleBuilder builder, string methodName,
        OrderedDictionary raw)
    {
        return raw
            .Cast<DictionaryEntry>()
            .Select((kvp, i) => ParseParamInfo(builder, methodName, kvp.Key.ToString() ?? $"arg{i + 1}", kvp.Value))
            .ToArray();
    }

    internal static TypeInformation ParseParamInfo(ModuleBuilder builder, string methodName, string name, object? value,
        bool forReturn = false)
    {
        PSObject? valuePSObj = null;

        if (value is PSObject)
        {
            valuePSObj = (PSObject)value;
            value = valuePSObj.BaseObject;
        }
        else if (value != null)
        {
            valuePSObj = PSObject.AsPSObject(value);
        }

        MarshalAsAttribute? marshalAs = null;
        if (valuePSObj != null)
        {
            PSNoteProperty? marshalAsInfo = valuePSObj.Properties
                .Match(Library.MARSHAL_AS_NOTE_NAME, PSMemberTypes.NoteProperty)
                .Cast<PSNoteProperty>()
                .FirstOrDefault();

            marshalAs = (MarshalAsAttribute?)marshalAsInfo?.Value;
        }

        Type valueType;
        if (value is PSReference refValue)
        {
            if (refValue.Value is Type refType)
            {
                valueType = refType.MakeByRefType();
            }
            else
            {
                valueType = (refValue.Value?.GetType() ?? typeof(IntPtr)).MakeByRefType();
            }
        }
        else if (value is Type paramType)
        {
            valueType = paramType;
        }
        else if (value is ScriptBlock sbk)
        {
            ScriptBlockDelegate info = new(sbk);
            TypeInformation returnType = info.GetReturnType();
            TypeInformation[] parameterTypes = info.GetParameterTypes();

            valueType = CreateDelegateType(builder, $"{methodName}_{name}_Delegate", returnType, parameterTypes);
        }
        else
        {
            valueType = value?.GetType() ?? typeof(IntPtr);
        }

        if (!forReturn && valueType == typeof(IntPtr))
        {
            valueType = typeof(Nullable<IntPtr>);
        }

        return new(name, valueType, marshalAs: marshalAs);
    }
}
