<#
import-module <filepath>\own.ps1 first
#>
Function get-own
{
  Param
  (
    #search $username in object owners
    [Parameter(Mandatory=$true)]
    [String]$username,

    #look objects recursively in this $startPath
    [Parameter(Mandatory=$true)]
    [String]$startPath
  )

  Process
  {
  #search recursively in $startPath, object owned by $username
  Get-ChildItem $startPath  -Force -Recurse -ErrorAction 'SilentlyContinue' | `
    Get-Acl | Where { $_.Owner -eq $username } | `
    Format-List -Property PsPath
  }
}

Function list-own
{
  Param
  (
    #look objects recursively in this $startPath
    [Parameter(Mandatory=$true)]
    [String]$startPath
  )

  Process
  {
  #list all object owners, recursively in $startPath
  Get-ChildItem $startPath  -force -Recurse -ErrorAction 'SilentlyContinue' | `
    Get-Acl | `
    Format-List -Property PsPath, Owner
  }
}
