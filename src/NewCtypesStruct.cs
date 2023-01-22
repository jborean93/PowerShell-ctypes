using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

using ReflectionTA = System.Reflection.TypeAttributes;

namespace Ctypes;

[Alias("ctypes_struct")]
[Cmdlet(VerbsCommon.New, "CtypesStruct")]
public sealed class CtypesStructCommand : PSCmdlet
{
    [Parameter(
        Mandatory = true,
        Position = 0
    )]
    public string Name { get; set; } = "";

    [Parameter(
        Mandatory = true,
        Position = 1
    )]
    public ScriptBlock Body { get; set; } = default!;

    [Parameter()]
    public LayoutKind LayoutKind { get; set; } = System.Runtime.InteropServices.LayoutKind.Sequential;

    [Parameter()]
    public CharSet? CharSet { get; set; }

    [Parameter()]
    public Int32? Pack { get; set; }

    protected override void EndProcessing()
    {
        if (!(Body.Ast is ScriptBlockAst ast))
        {
            string msg = $"ScriptBlock Ast is not the expect ScriptBlockAst but was {Body.Ast.GetType().Name}";
            ThrowTerminatingError(new ErrorRecord(
                new ArgumentException(msg),
                "UnknownAst",
                ErrorCategory.InvalidArgument,
                Body));
            return;
        }

        if (
            ast.BeginBlock != null ||
            ast.ProcessBlock != null ||
            ast.EndBlock == null ||
            !ast.EndBlock.Unnamed
        )
        {
            string msg = "ctypes_struct must not contain explicit begin, process, or end blocks";
            ThrowTerminatingError(new ErrorRecord(
                new ArgumentException(msg),
                "InvalidStructAst",
                ErrorCategory.InvalidArgument,
                Body));
            return;
        }

        List<StructFieldInfo> fields = new();

        foreach (StatementAst statement in ast.EndBlock.Statements)
        {
            try
            {
                fields.Add(ParseFieldStatement(statement));
            }
            catch (ArgumentException e)
            {
                ThrowTerminatingError(new ErrorRecord(
                    e,
                    "InvalidStructFieldExpression",
                    ErrorCategory.InvalidArgument,
                    statement));
                return;
            }
        }

        string assemblyName = $"Ctypes.Struct.{Name}";
        AssemblyBuilder assemblyBuilder = AssemblyBuilder.DefineDynamicAssembly(
            new(assemblyName), AssemblyBuilderAccess.Run);
        ModuleBuilder mb = assemblyBuilder.DefineDynamicModule(assemblyName);

        ReflectionTA typeAttributes = ReflectionTA.Public | ReflectionTA.Sealed;
        if (LayoutKind == System.Runtime.InteropServices.LayoutKind.Sequential)
        {
            typeAttributes |= ReflectionTA.SequentialLayout;
        }
        else if (LayoutKind == System.Runtime.InteropServices.LayoutKind.Explicit)
        {
            typeAttributes |= ReflectionTA.ExplicitLayout;
        }
        else
        {
            typeAttributes |= ReflectionTA.AutoLayout;
        }

        CustomAttributeBuilder structLayout = CreateStructLayoutAttribute(LayoutKind, CharSet, Pack);

        TypeBuilder tb = mb.DefineType(Name, typeAttributes, typeof(ValueType));
        tb.SetCustomAttribute(structLayout);

        foreach (StructFieldInfo info in fields)
        {
            FieldAttributes attr = FieldAttributes.Public;
            List<CustomAttributeBuilder> customAttrs = new();

            if (info.MarshalAs != null)
            {
                customAttrs.Add(CreateMarshalAsAttribute(info.MarshalAs));
                attr |= FieldAttributes.HasFieldMarshal;
            }
            if (info.FieldOffset != null)
            {
                customAttrs.Add(CreateFieldOffsetAttribute(info.FieldOffset));
            }

            FieldBuilder field = tb.DefineField(info.Name, info.FieldType, attr);
            if (info.DefaultValue != null)
            {
                field.SetConstant(info.DefaultValue);
            }
            foreach (CustomAttributeBuilder a in customAttrs)
            {
                field.SetCustomAttribute(a);
            }
        }

        tb.CreateType();
    }

    private static StructFieldInfo ParseFieldStatement(StatementAst ast)
    {
        ExpressionAst? exp = null;
        if (
            ast is PipelineAst pipeline &&
            pipeline.PipelineElements.Count == 1 &&
            pipeline.PipelineElements[0] is CommandExpressionAst cmdExp
        )
        {
            exp = cmdExp.Expression;
        }

        if (exp == null)
        {
            throw new ArgumentException(
                "ctypes_struct must only contain [type]$FieldName lines for each struct field");
        }

        Type fieldType = typeof(IntPtr);
        MarshalAsAttribute? marshalAs = null;
        FieldOffsetAttribute? fieldOffset = null;

        while (true)
        {
            if (exp is AttributedExpressionAst attrExp)
            {
                if (attrExp is ConvertExpressionAst convExp)
                {
                    // [Type]$Var
                    fieldType = convExp.StaticType;
                }
                else if (
                    attrExp.Attribute.TypeName.FullName.ToLowerInvariant() == "marshalas" &&
                    attrExp.Attribute is AttributeAst marshalAsAttr
                )
                {
                    // [MarshalAs(...)][Type]$Var
                    marshalAs = ParseMarshalAs(marshalAsAttr);
                }
                else if (
                    attrExp.Attribute.TypeName.FullName.ToLowerInvariant() == "fieldoffset" &&
                    attrExp.Attribute is AttributeAst fieldOffsetAttr
                )
                {
                    // [FieldOffset(...)][Type]$Var
                    fieldOffset = ParseFieldOffset(fieldOffsetAttr);
                }
                else
                {
                    throw new ArgumentException(
                        $"Unknown attribute '{attrExp.Attribute.TypeName.FullName}', only MarshalAs and FieldOffset supported");
                }

                exp = attrExp.Child;
            }
            else
            {
                break;
            }
        }

        if (exp is VariableExpressionAst varExp && !varExp.Splatted)
        {
            return new(varExp.VariablePath.UserPath, fieldType, marshalAs, fieldOffset);
        }

        throw new ArgumentException(
            $"ctypes_struct line '{ast.ToString()}' must be a variable expression [type]$FieldName");
    }

    private static FieldOffsetAttribute ParseFieldOffset(AttributeAst attr)
    {
        if (attr.PositionalArguments.Count != 1)
        {
            throw new ArgumentException(
                $"Expecting 1 argument for FieldOffset attribute but found {attr.PositionalArguments.Count}");
        }

        FieldOffsetAttribute fieldOffset = new(GetAttributeIntValue(attr.PositionalArguments[0], "FieldOffset"));
        return fieldOffset;
    }

    private static MarshalAsAttribute ParseMarshalAs(AttributeAst attr)
    {
        if (attr.PositionalArguments.Count != 1)
        {
            throw new ArgumentException(
                $"Expecting 1 argument for MarshalAs attribute but found {attr.PositionalArguments.Count}");
        }

        MarshalAsAttribute? marshalAs = null;
        if (TryGetAttributeValue(attr.PositionalArguments[0], out var intMarshalAs, out var stringMarshalAs))
        {
            if (stringMarshalAs != null && Enum.TryParse<UnmanagedType>(stringMarshalAs, out var unmanagedType))
            {
                marshalAs = new(unmanagedType);
            }
            else if (intMarshalAs != null && intMarshalAs < short.MaxValue)
            {
                marshalAs = new((short)intMarshalAs);
            }
        }

        if (marshalAs == null)
        {
            throw new ArgumentException($"Failed to extract MarshalAs UnmanagedType value for {attr.ToString()}");
        }

        foreach (NamedAttributeArgumentAst arg in attr.NamedArguments)
        {
            switch (arg.ArgumentName.ToLowerInvariant())
            {
                case "arraysubtype":
                    marshalAs.ArraySubType = GetAttributeEnumValue<UnmanagedType>(arg.Argument, "ArraySubType");
                    break;

                case "sizeconst":
                    marshalAs.SizeConst = GetAttributeIntValue(arg.Argument, "SizeConst");
                    break;

                default:
                    throw new ArgumentException(
                        $"Unsupported MarshalAs named argument '{arg.ArgumentName}', expecting ArraySubType or SizeConst");
            }
        }

        return marshalAs;
    }

    private static string GetAttributeStringValue(ExpressionAst ast, string attributeName)
    {
        if (TryGetAttributeValue(ast, out var _, out var strValue) && strValue != null)
        {
            return (string)strValue;
        }

        throw new ArgumentException($"Failed to extract expected string value from {attributeName}");
    }

    private static int GetAttributeIntValue(ExpressionAst ast, string attributeName)
    {
        if (TryGetAttributeValue(ast, out var intValue, out var _) && intValue != null)
        {
            return (int)intValue;
        }

        throw new ArgumentException($"Failed to extract expected int value for {attributeName}");
    }

    private static T GetAttributeEnumValue<T>(ExpressionAst ast, string attributeName)
        where T : struct
    {
        if (TryGetAttributeValue(ast, out var intValue, out var strValue))
        {
            if (intValue != null)
            {
                return (T)(object)intValue;
            }

            if (strValue != null && Enum.TryParse<T>(strValue, true, out var enumValue))
            {
                return enumValue;
            }
        }

        Type enumType = typeof(T);
        throw new ArgumentException($"Failed to extract expected enum {enumType.Name} value for {attributeName}");
    }

    private static bool TryGetAttributeValue(ExpressionAst ast, out int? intValue, out string? stringValue)
    {
        intValue = null;
        stringValue = null;
        if (ast is StringConstantExpressionAst stringExp)
        {
            stringValue = stringExp.Value;
            return true;
        }
        else if (ast is ConstantExpressionAst constExp)
        {
            bool res = int.TryParse(constExp.Value.ToString(), out var extractedInt);
            intValue = extractedInt;
            return res;
        }

        return false;
    }

    private static CustomAttributeBuilder CreateStructLayoutAttribute(LayoutKind layoutKind, CharSet? charSet = null,
        int? pack = null)
    {
        List<FieldInfo> fields = new();
        List<object> values = new();

        if (charSet != null)
        {
            fields.Add(ReflectionInfo.StructLayoutCharSet);
            values.Add(charSet);
        }
        if (pack != null)
        {
            fields.Add(ReflectionInfo.StructLayoutPackField);
            values.Add(pack);
        }

        return new(
            ReflectionInfo.StructLayoutCtor,
            new object[] { layoutKind },
            fields.ToArray(),
            values.ToArray()
        );
    }

    public static CustomAttributeBuilder CreateMarshalAsAttribute(MarshalAsAttribute value)
    {
        List<FieldInfo> fields = new();
        List<object> values = new();

        if (value.SizeConst != 0)
        {
            fields.Add(ReflectionInfo.MarshalAsSizeConstField);
            values.Add(value.SizeConst);
        }

        if (value.ArraySubType != 0)
        {
            fields.Add(ReflectionInfo.MarshalAsArraySubTypeField);
            values.Add(value.ArraySubType);
        }

        return new(
            ReflectionInfo.MarshalAsCtor,
            new object[] { value.Value },
            fields.ToArray(),
            values.ToArray()
        );
    }

    public static CustomAttributeBuilder CreateFieldOffsetAttribute(FieldOffsetAttribute value)
    {
        return new(
            ReflectionInfo.FieldOffsetCtor,
            new object[] { value.Value }
        );
    }
}

internal class StructFieldInfo
{
    public string Name { get; }
    public Type FieldType { get; }
    public MarshalAsAttribute? MarshalAs { get; }
    public FieldOffsetAttribute? FieldOffset { get; }
    public object? DefaultValue { get; set; }

    public StructFieldInfo(string name, Type fieldType, MarshalAsAttribute? marshalAs,
        FieldOffsetAttribute? fieldOffset)
    {
        Name = name;
        FieldType = fieldType;
        MarshalAs = marshalAs;
        FieldOffset = fieldOffset;
    }
}
