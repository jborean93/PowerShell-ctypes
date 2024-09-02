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

        List<TypeInformation> fields = new();

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

        foreach (TypeInformation info in fields)
        {
            FieldAttributes attr = FieldAttributes.Public;
            List<CustomAttributeBuilder> customAttrs = new();

            CustomAttributeBuilder? marshalAsBuilder = info.CreateMarshalAsAttribute();
            if (marshalAsBuilder != null)
            {
                customAttrs.Add(marshalAsBuilder);
                attr |= FieldAttributes.HasFieldMarshal;
            }

            CustomAttributeBuilder? fieldOffsetBuilder = info.CreateFieldOffsetAttribute();
            if (fieldOffsetBuilder != null)
            {
                customAttrs.Add(fieldOffsetBuilder);
            }

            Type fieldType = info.Type;
#if NET6_0_OR_GREATER
            // Enums in pwsh are defined with RunAndCollect and cannot be used
            // in an assembly that is also not collectible. Copy across the
            // enum to the current assembly.
            if (fieldType.IsSubclassOf(typeof(Enum)) && fieldType.IsCollectible)
            {
                fieldType = CopyEnumToAssembly(fieldType, mb);
            }
#endif

            FieldBuilder field = tb.DefineField(info.Name, fieldType, attr);
            foreach (CustomAttributeBuilder a in customAttrs)
            {
                field.SetCustomAttribute(a);
            }
        }

        tb.CreateType();
    }

    private static TypeInformation ParseFieldStatement(StatementAst ast)
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
                    marshalAs = AstParser.ParseMarshalAs(marshalAsAttr);
                }
                else if (
                    attrExp.Attribute.TypeName.FullName.ToLowerInvariant() == "fieldoffset" &&
                    attrExp.Attribute is AttributeAst fieldOffsetAttr
                )
                {
                    // [FieldOffset(...)][Type]$Var
                    fieldOffset = AstParser.ParseFieldOffset(fieldOffsetAttr);
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
            return new(varExp.VariablePath.UserPath, fieldType, marshalAs: marshalAs, fieldOffset: fieldOffset);
        }

        throw new ArgumentException(
            $"ctypes_struct line '{ast.ToString()}' must be a variable expression [type]$FieldName");
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

#if NET6_0_OR_GREATER
    private static Type CopyEnumToAssembly(Type enumToCopy, ModuleBuilder mb)
    {
        Type underlyingType = Enum.GetUnderlyingType(enumToCopy);
        EnumBuilder eb = mb.DefineEnum(enumToCopy.FullName!, ReflectionTA.Public,
            underlyingType);

        if (enumToCopy.GetCustomAttribute<FlagsAttribute>() != null)
        {
            CustomAttributeBuilder flagsAttr = new(
                ReflectionInfo.FlagsCtor,
                Array.Empty<object>());
            eb.SetCustomAttribute(flagsAttr);
        }

        FieldInfo[] fields = enumToCopy.GetFields(BindingFlags.Static | BindingFlags.Public);
        foreach (FieldInfo field in fields)
        {
            eb.DefineLiteral(field.Name, Convert.ChangeType(field.GetValue(null), underlyingType));
        }

        return eb.CreateType()!;
    }
#endif
}
