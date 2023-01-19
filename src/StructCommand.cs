using System;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

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
    public LayoutKind? LayoutKind { get; set; }

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

        foreach (StatementAst statement in ast.EndBlock.Statements)
        {
            if (
                !(statement is PipelineAst pipeline) ||
                pipeline.PipelineElements.Count != 1 ||
                !(pipeline.PipelineElements[0] is CommandExpressionAst cmdExp)
            )
            {
                string msg = "ctypes_struct must only contain [type]$FieldName lines for each struct field";
                ThrowTerminatingError(new ErrorRecord(
                    new ArgumentException(msg),
                    "InvalidStructBody",
                    ErrorCategory.InvalidArgument,
                    Body));
                return;
            }

            ExpressionAst exp = cmdExp.Expression;
            Type? fieldType = null;
            MarshalAsAttribute? marshalAs = null;

            while (true)
            {
                if (exp is AttributedExpressionAst attrExp)
                {
                    // [Attribute()]...
                    if (attrExp is ConvertExpressionAst convExp)
                    {
                        // [Type]$Var
                        fieldType = convExp.StaticType;
                    }
                    else if (
                        attrExp.Attribute.TypeName.FullName == "MarshalAs" &&
                        attrExp.Attribute is AttributeAst marshalAsAttr
                    )
                    {
                        // [MarshalAs(...)][Type]$Var
                        try
                        {
                            marshalAs = ParseMarshalAs(marshalAsAttr);
                        }
                        catch (Exception e)
                        {
                            ThrowTerminatingError(new ErrorRecord(
                                e,
                                "InvalidStructFieldMarshalAsAttribute",
                                ErrorCategory.InvalidArgument,
                                Body));
                            return;
                        }
                    }
                    // FIXME: Support FieldOffset
                    else
                    {
                        string msg = $"Unknown attribute '{attrExp.Attribute.TypeName.FullName}', only MarshalAs supported";
                        ThrowTerminatingError(new ErrorRecord(
                            new ArgumentException(msg),
                            "InvalidStructFieldAttribute",
                            ErrorCategory.InvalidArgument,
                            Body));
                        return;
                    }

                    exp = attrExp.Child;
                }
                else
                {
                    break;
                }
            }

            string fieldName;
            if (exp is VariableExpressionAst varExp && !varExp.Splatted)
            {
                fieldName = varExp.VariablePath.UserPath;
            }
            else
            {
                string msg = $"ctypes_struct line '{exp.ToString()}' must be a variable expression [type]$FieldName";
                ThrowTerminatingError(new ErrorRecord(
                    new ArgumentException(msg),
                    "InvalidStructLineExpression",
                    ErrorCategory.InvalidArgument,
                    Body));
                return;
            }

            if (fieldType == null)
            {
                fieldType = typeof(object);
            }
        }
    }

    private static MarshalAsAttribute ParseMarshalAs(AttributeAst attr)
    {
        if (attr.PositionalArguments.Count != 1)
        {
            throw new ArgumentException(
                $"Expecting 1 argument for MarshalAs attribute but found {attr.PositionalArguments.Count}");
        }

        MarshalAsAttribute? marshalAs = null;
        if (attr.PositionalArguments[0] is StringConstantExpressionAst stringExp)
        {
            if (Enum.TryParse<UnmanagedType>(stringExp.Value, out var unmanagedType))
            {
                marshalAs = new(unmanagedType);
            }
        }
        else if (attr.PositionalArguments[0] is ConstantExpressionAst constExp)
        {
            if (short.TryParse(constExp.Value.ToString(), out var unmanagedType))
            {
                marshalAs = new(unmanagedType);
            }
        }

        if (marshalAs == null)
        {
            throw new ArgumentException($"Failed to extract MarshalAs UnmanagedType value for {attr.ToString()}");
        }

        foreach (NamedAttributeArgumentAst arg in attr.NamedArguments)
        {
            switch (arg.ArgumentName)
            {
                case "SizeConst":
                    marshalAs.SizeConst = int.Parse(arg.Argument.SafeGetValue().ToString());
                    break;

                default:
                    throw new ArgumentException(
                        $"Unsupported MarshalAs named argument '{arg.ArgumentName}', expecting SizeConst");
            }
        }

        return marshalAs;
    }
}
