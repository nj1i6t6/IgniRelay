$ErrorActionPreference = "SilentlyContinue"
$outFile = "c:\Users\radio\Downloads\IDE\CoReM\resqmesh_app\device_check.txt"

# Kill flutter run processes
taskkill /F /IM dart.exe 2>$null
Start-Sleep -Seconds 2

# Check mbtiles on device  
$result = @()
$result += "=== Device files ==="
$result += (adb shell "run-as network.resqmesh find . -name '*.mbtiles' -exec ls -la {} \;" 2>&1)
$result += ""
$result += "=== App documents ==="
$result += (adb shell "run-as network.resqmesh ls -la files/" 2>&1)
$result += ""
$result += "=== Logcat flutter ==="
$result += (adb logcat -d -s flutter --format brief 2>&1 | Select-String "Map|MBTiles|error|init" | Select-Object -Last 30)

$result | Out-File -FilePath $outFile -Encoding utf8
Write-Host "Done: $outFile"
