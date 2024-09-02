using System;
using System.Collections.Generic;
using System.Management.Automation.Language;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

namespace Ctypes;

internal sealed class AstParser
{
    public static FieldOffsetAttribute ParseFieldOffset(AttributeAst attr)
    {
        if (attr.PositionalArguments.Count != 1)
        {
            throw new ArgumentException(
                $"Expecting 1 argument for FieldOffset attribute but found {attr.PositionalArguments.Count}");
        }

        FieldOffsetAttribute fieldOffset = new(GetAttributeIntValue(attr.PositionalArguments[0], "FieldOffset"));
        return fieldOffset;
    }

    public static MarshalAsAttribute ParseMarshalAs(AttributeAst attr)
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
        else if (ast is MemberExpressionAst memberExp && memberExp.Member is StringConstantExpressionAst memberValue)
        {
            stringValue = memberValue.Value;
            return true;
        }

        return false;
    }
}

internal sealed class TypeInformation
{
    public string Name { get; }
    public Type Type { get; }
    public bool IsIn { get; }
    public bool IsOut { get; }
    public MarshalAsAttribute? MarshalAs { get; }
    public FieldOffsetAttribute? FieldOffset { get; }
    public ScriptBlockDelegate? DelegateInfo { get; }

    public TypeInformation(string name, Type type, MarshalAsAttribute? marshalAs = null,
        FieldOffsetAttribute? fieldOffset = null, bool isIn = false, bool isOut = false,
        ScriptBlockDelegate? delegateInfo = null)
    {
        Type = type;
        Name = name;
        MarshalAs = marshalAs;
        FieldOffset = fieldOffset;
        IsIn = isIn;
        IsOut = isOut;
        DelegateInfo = delegateInfo;
    }

    public CustomAttributeBuilder? CreateMarshalAsAttribute()
    {
        if (MarshalAs == null)
        {
            return null;
        }

        List<FieldInfo> fields = new();
        List<object> values = new();

        if (MarshalAs.SizeConst != 0)
        {
            fields.Add(ReflectionInfo.MarshalAsSizeConstField);
            values.Add(MarshalAs.SizeConst);
        }

        if (MarshalAs.ArraySubType != 0)
        {
            fields.Add(ReflectionInfo.MarshalAsArraySubTypeField);
            values.Add(MarshalAs.ArraySubType);
        }

        return new(
            ReflectionInfo.MarshalAsCtor,
            new object[] { MarshalAs.Value },
            fields.ToArray(),
            values.ToArray()
        );
    }

    public CustomAttributeBuilder? CreateFieldOffsetAttribute()
    {
        if (FieldOffset == null)
        {
            return null;
        }

        return new(
            ReflectionInfo.FieldOffsetCtor,
            new object[] { FieldOffset.Value }
        );
    }
}
