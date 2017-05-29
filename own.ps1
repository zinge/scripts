<#
import-module first
#>
Function get-own
{
  Param
  (
    [Parameter(Mandatory=$true)]
    [String]$username,

    [Parameter(Mandatory=$true)]
    [String]$startPath
  )

  Process
  {

  Get-ChildItem $startPath  -force -Recurse -ErrorAction 'SilentlyContinue' | `
    Get-Acl | Where-Object{ $_.Owner -eq $username } | `
    Format-List -Property PsPath
  }
}

Function list-own
{
  Param
  (
    [Parameter(Mandatory=$true)]
    [String]$startPath
  )

  Process
  {

  Get-ChildItem $startPath  -force -Recurse -ErrorAction 'SilentlyContinue' | `
    Get-Acl | Where-Object{ $_.Owner } | `
    Format-List -Property PsPath, Owner
  }
}
