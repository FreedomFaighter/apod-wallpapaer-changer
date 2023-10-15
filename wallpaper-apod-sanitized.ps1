<#PSScriptInfo
    .VERSION 1.0.0.0
    .GUID cfc2e719-67d8-4722-b594-3d198a1206c7
    .FILENAME Set-DesktopWallpaper.ps1
#>
function Set-DesktopWallpaper {
    <#
    .DESCRIPTION
        Sets a desktop background image
    .PARAMETER PicturePath
        Defines the path to the picture to use for background
    .PARAMETER Style
        Defines the style of the wallpaper. Valid values are, Tiled, Centered, Stretched, Fill, Fit, Span
    .EXAMPLE
        Set-DesktopWallpaper -PicturePath "C:\pictures\picture1.jpg" -Style Fill
    .EXAMPLE
        Set-DesktopWallpaper -PicturePath "C:\pictures\picture2.png" -Style Centered
    .NOTES
        Supports jpg, png and bmp files.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][String]$PicturePath,
        [ValidateSet('Tiled', 'Centered', 'Stretched', 'Fill', 'Fit', 'Span')]$Style = 'Fill'
    )


    BEGIN {
        $Definition = @"
[DllImport("user32.dll", EntryPoint = "SystemParametersInfo")]
public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@

        Add-Type -MemberDefinition $Definition -Name Win32SystemParametersInfo -Namespace Win32Functions
        $Action_SetDeskWallpaper = [int]20
        $Action_UpdateIniFile = [int]0x01
        $Action_SendWinIniChangeEvent = [int]0x02

        $HT_WallPaperStyle = @{
            'Tiles'     = 0
            'Centered'  = 0
            'Stretched' = 2
            'Fill'      = 10
            'Fit'       = 6
            'Span'      = 22
        }

        $HT_TileWallPaper = @{
            'Tiles'     = 1
            'Centered'  = 0
            'Stretched' = 0
            'Fill'      = 0
            'Fit'       = 0
            'Span'      = 0
        }

    }


    PROCESS {
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name wallpaperstyle -Value $HT_WallPaperStyle[$Style]
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name tilewallpaper -Value $HT_TileWallPaper[$Style]
        $null = [Win32Functions.Win32SystemParametersInfo]::SystemParametersInfo($Action_SetDeskWallpaper, 0, $PicturePath, ($Action_UpdateIniFile -bor $Action_SendWinIniChangeEvent))
    }
}

$exitCode = 0
$govAPIKey = $args[0]
if($govAPIKey.Length -ne 40)
{
	Write-Output "Key invalid length"
	$exitCode = $exitCode + 1
}	
$backgroundPath = "$home\Pictures\APOD"
$pathAccessible = Test-Path -Path $backgroundPath
if($pathAccessible -eq $false)
{
    mkdir -Path $backgroundPath
	$exitCode = $exitCode + 2
}
else
{
    $tryToConnectToapiNasaGov = (Test-NetConnection api.nasa.gov -Port 443 -InformationLevel Detailed)
    if($tryToConnectToapiNasaGov -eq $false)
    {
	    $exitCode = $exitCode + 4
        Exit $exitCode
    }
    else
    {
        $uriBase = "https://api.nasa.gov/planetary/apod?hd=true&api_key=" + $govAPIKey
        $jsonObject = Invoke-WebRequest -Uri $uriBase -UseBasicParsing | ConvertFrom-Json
        $pathStillAccessible = Test-Path -Path $backgroundPath
        if([string]::IsNullOrEmpty($jsonObject.hdurl))
        {
            Write-Output "hdurl path of json object from apod api is null or empty"
            $exitCode = $exitCode + 32
            Exit $exitCode
        }
        $fileName = Split-Path $jsonObject.hdurl -leaf
        if($pathStillAccessible -eq $False)
        {
	        $exitCode = $exitCode + 8
            Exit $exitCode
        }
        elseif($fileName.EndsWith(".png") -or $fileName.EndsWith(".jpg"))
        {
	        
            $filePath = Join-Path -Path $backgroundPath -ChildPath $fileName
        	if(!(Test-Path -Path $filePath))
	        {
		        Start-BitsTransfer -Source $jsonObject.hdurl -Destination $filePath
	        }
            $checksumFilePath = Join-Path -Path $backgroundPath -ChildPath "Checksums"
            $checksumFilePath = Join-Path -Path $checksumFilePath -ChildPath $fileName
	        if(Test-path -Path $filePath)
	        {
		        $md5hashFilePath = -join($checksumFilePath, ".md5")
		        $sha512hastFilePath = -join($filePath, ".sha512")
		        Get-FileHash $filePath -Algorithm MD5 | Format-List | Out-File -NoClobber -Append -FilePath $md5hashFilePath  
		        Get-FileHash $filePath -Algorithm SHA512 | Format-List | Out-File -NoClobber -Append -FilePath $sha512hastFilePath  
		        Set-DesktopWallpaper("$filePath")
	        }
        }
        else
        {
            Write-Output "Current hdurl on json object is not jpg or png"
        }
    }
}

Exit $exitCode
