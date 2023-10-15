$yesOrNoResponse = Read-Host -Prompt "Attempt to get new APOD image from NASA's APOD api? (y?) anything other then y for yes will exit the script"
$exitCode = 0
if($yesOrNoResponse -ne 'y')
{
    $exitCode = $exitCode + 64
    Exit $exitCode
}

$setwallpapersrc=@'
using System.Runtime.InteropServices;
public class wallpaper
{
    public const int SetDesktopWallpaper = 20;
    public const int UpdateIniFile = 0x01;
    public const int SendWinIniChange = 0x02;
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
    public static void SetWallpaper (string path)
    {
        SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
    }
}
'@

Add-Type -TypeDefinition $setwallpapersrc

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
		        [wallpaper]::SetWallpaper("$filePath")
	        }
        }
        else
        {
            Write-Output "Current hdurl on json object is not jpg or png"
        }
    }
}

Exit $exitCode
