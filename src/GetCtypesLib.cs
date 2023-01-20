using System;
using System.Management.Automation;

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
