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

$govAPIKey = $args[0]
$getHDImage = $args[1]
$backgroundPath = "$home\Pictures\APOD"
$tryToConnectToapiNasaGov = (Test-NetConnection api.nasa.gov -Port 443 -InformationLevel Detailed)
$uriBase = "https://api.nasa.gov/planetary/apod?hd=" + $getHDImage + "&api_key=" + $govAPIKey
$jsonObject = Invoke-WebRequest -Uri $uriBase -UseBasicParsing | ConvertFrom-Json
$pathStillAccessible = Test-Path -Path $backgroundPath
$fileName = Split-Path $jsonObject.hdurl -leaf
$filePath = Join-Path -Path $backgroundPath -ChildPath $fileName
Start-BitsTransfer -Source $jsonObject.hdurl -Destination $filePath
[wallpaper]::SetWallpaper("$filePath")
Write-Output "Current hdurl on json object is not jpg or png"
