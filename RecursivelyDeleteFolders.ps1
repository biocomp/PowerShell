 param (
    [Parameter(Mandatory=$true)][string]$dirName
 )

 Get-ChildItem $dirName -Recurse | Remove-Item -Force -Recurse -WhatIf