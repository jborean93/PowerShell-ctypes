using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Language;
using System.Runtime.InteropServices;

namespace Ctypes;

internal sealed class ScriptBlockDelegate
{
    private ScriptBlockAst _scriptAst;

    public ScriptBlock Action { get; }

    public ScriptBlockDelegate(ScriptBlock action)
    {
        Action = action;
        _scriptAst = (ScriptBlockAst)action.Ast;
    }

    public TypeInformation GetReturnType()
    {
        return ProcessOutputType(
            (IEnumerable<AttributeAst>?)_scriptAst.ParamBlock?.Attributes ?? Array.Empty<AttributeAst>());
    }

    public TypeInformation[] GetParameterTypes()
    {
        return _scriptAst.ParamBlock?.Parameters
            ?.Select(p => ProcessParameterType(p))
            ?.ToArray() ?? Array.Empty<TypeInformation>();
    }

    private static TypeInformation ProcessOutputType(IEnumerable<AttributeAst> paramAttributes)
    {
        MarshalAsAttribute? marshalAs = null;

        Type? outputType = null;
        foreach (AttributeBaseAst attr in paramAttributes)
        {
            if (attr is not AttributeAst ast)
            {
                continue;
            }

            if (
                ast.TypeName.GetReflectionType() == typeof(OutputTypeAttribute) &&
                ast.PositionalArguments.Count == 1 &&
                ast.PositionalArguments[0] is TypeExpressionAst outputTypeAst
            )
            {
                outputType = outputTypeAst.TypeName.GetReflectionType();
            }
            else if (marshalAs == null)
            {
                marshalAs = TryParseMarshalAs(ast);
            }
        }

        return new("", outputType ?? typeof(void), marshalAs: marshalAs);
    }

    private static TypeInformation ProcessParameterType(ParameterAst parameter)
    {

        MarshalAsAttribute? marshalAs = null;
        bool isIn = false;
        bool isOut = false;

        Type paramType = paramType = parameter.StaticType;
        if (paramType == typeof(object) && parameter.Attributes.Count == 0)
        {
            // Default to IntPtr if not explicit type was specified.
            paramType = typeof(IntPtr);
        }
        foreach (AttributeBaseAst attr in parameter.Attributes)
        {
            if (attr is not AttributeAst ast)
            {
                continue;
            }

            isIn = isIn || ast.TypeName.GetReflectionType() == typeof(InAttribute);
            isOut = isOut || ast.TypeName.GetReflectionType() == typeof(OutAttribute);
            if (marshalAs == null)
            {
                marshalAs = TryParseMarshalAs(ast);
            }
        }

        return new(parameter.Name.VariablePath.UserPath, paramType, marshalAs: marshalAs,
            isIn: isIn, isOut: isOut);
    }

    private static MarshalAsAttribute? TryParseMarshalAs(AttributeAst ast)
    {
        try
        {
            return AstParser.ParseMarshalAs(ast);
        }
        catch (ArgumentException)
        {
            return null;
        }
    }
}
