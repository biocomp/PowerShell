function PSUsing
{
    param
    (
        [IDisposable] $disposable,
        [ScriptBlock] $scriptBlock
    )
 
    try
    {
        & $scriptBlock
    }
    finally
    {
        if ($disposable -ne $null)
        {
            $disposable.Dispose()
        }
    }
}

function Get-ExifProperty
{
    param
    (
        [string] $ImagePath,
        [int] $ExifTagCode
    )
 
    $fullPath = (Resolve-Path $ImagePath).Path
 
    PSUsing ($fs = [System.IO.File]::OpenRead($fullPath)) `
    {
        PSUsing ($image = [System.Drawing.Image]::FromStream($fs, $false, $false)) `
        {
            if (-not $image.PropertyIdList.Contains($ExifTagCode))
            {
                return $null
            }
 
            $propertyItem = $image.GetPropertyItem($ExifTagCode)
            $valueBytes = $propertyItem.Value
            $value = [System.Text.Encoding]::ASCII.GetString($valueBytes) -replace "`0$"
            return $value
        }
    }
}


$ExifTagCode_DateTimeOriginal = 0x9003
 
function Get-DateTaken
{
    param
    (
        [string] $ImagePath
    )
 
    $str = Get-ExifProperty -ImagePath $ImagePath -ExifTagCode $ExifTagCode_DateTimeOriginal
 
    if ($str -eq $null)
    {
        return $null
    }
 
    $dateTime = [DateTime]::MinValue
    if ([DateTime]::TryParseExact($str, "yyyy:MM:dd HH:mm:ss", $null, [System.Globalization.DateTimeStyles]::None, [ref] $dateTime))
    {
        return $dateTime
    }
 
    return $null
}

function Sort-Photos
{
    param(
        [string] $SrcFolder,
        [string] $DstFolder,
        [Switch] $ByYear,
        [Switch] $ByMonth,
        [Switch] $ByDay
    )

    if ($SrcFolder -eq $DstFolder) {
        Throw "Source '" + $SrcFolder + "' and destination '" + $DstFolder + "' folders should not match"
    }

    Write ("Sorting photos from $SrcFolder to $DstFolder...")
  
    # Get the files which should be moved, without folders
    $files = Get-ChildItem $SrcFolder -Recurse | where {!$_.PsIsContainer }
  
    foreach ($file in $files)
    {
        $date = Get-DateTaken($file.FullName)

        if (!$date) {
            Write-Error("'" + $file.FullName + "' did not have EXIF date taken. Trying to use modified date: " + $file.LastWriteTime)
            $date = $file.LastWriteTime
        }

        $year = $date.Year
        $month = $date.Month
        $day = $date.Day

        Write("---------")
        Write("Found file '" + $file.FullName + "', date taken: " + $date + ", year = " + $year + ", month = " + $month + ", day = " + $day)

        $newPath = $DstFolder
        if ($ByYear) {
            $newPath = [System.IO.Path]::Combine($newPath, $year)
        }
        
        if ($ByMonth) {
            $newPath = [System.IO.Path]::Combine($newPath, $month)
        }

        if ($ByDay) {
            $newPath = [System.IO.Path]::Combine($newPath, $day)
        }

        $newFileName = [System.IO.Path]::Combine($newPath, $file.Name)

        # Set Directory Path
        # Create directory if it doesn't exsist
        if (!(Test-Path $newPath))
        {
            New-Item $newPath -type directory
        }

        $suffix = 0
        while (Test-Path $newFileName) {
            $tempPath = [System.IO.Path]::Combine($newPath, $file.Name)
            $newFileName = [System.IO.Path]::Combine(
                [System.IO.Path]::GetDirectoryName($tempPath), [System.IO.Path]::GetFileNameWithoutExtension($tempPath))
            $newFileName = $newFileName + "--$suffix" +  [System.IO.Path]::GetExtension($tempPath)
            ++$suffix
        }

        
        Write("--> New file: " + $newFileName)

 
        # Move File to new location
        Move-Item -Path $file.FullName -Destination $newFileName
    }
}

Export-ModuleMember -Function Sort-Photos