# Fabrique l'APK du corps galaxie avec la chaîne d'outils locale (.toolchain) et, si demandé, l'installe sur le casque branché.
# Usage :  powershell -File outils\fabriquer.ps1            (essai automatique + APK)
#          powershell -File outils\fabriquer.ps1 -Installer (puis installation et lancement sur le Quest)
param([switch]$Installer, [switch]$SansEssai)
$ErrorActionPreference = 'Continue'
$projet = Split-Path $PSScriptRoot -Parent
$outils = Join-Path $projet '.toolchain'
$env:JAVA_HOME = (Get-ChildItem (Join-Path $outils 'jdk') -Directory | Select-Object -First 1).FullName
$env:ANDROID_HOME = Join-Path $outils 'sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"
$godot = Join-Path $outils 'godot\Godot_v4.4.1-stable_win64_console.exe'
Set-Location (Join-Path $projet 'godot')

# --xr-mode off : sur le PC, Godot ne cherche pas de casque (sinon une fenêtre d'alerte bloque tout)
& $godot --headless --xr-mode off --import 2>&1 | Select-String -Pattern 'SCRIPT ERROR|Parse Error|Failed' | Select-Object -First 20
if (-not $SansEssai) {
    $sortie = & $godot --headless --xr-mode off -- --essai 2>&1
    $sortie | Select-String -Pattern 'ESSAI|SCRIPT ERROR|Parse Error|Invalid|ÉCHEC' | Select-Object -First 30
    if (-not ($sortie -match 'ESSAI OK')) { Write-Output 'ARRÊT : essai automatique en échec'; exit 1 }
}
New-Item -ItemType Directory -Force build | Out-Null
Remove-Item build\corps-galaxie.apk -ErrorAction SilentlyContinue
# Godot reste parfois ouvert après l'export : on le lance à part, et on le ferme dès que l'export est terminé.
$proc = Start-Process $godot -ArgumentList '--headless','--xr-mode','off','--install-android-build-template','--export-debug','Quest','build/corps-galaxie.apk' -RedirectStandardOutput build\export.log -RedirectStandardError build\export-erreurs.log -PassThru -WindowStyle Hidden
$debut = Get-Date
while (-not $proc.HasExited -and ((Get-Date) - $debut).TotalMinutes -lt 25) {
    Start-Sleep -Seconds 5
    if ((Test-Path build\export.log) -and (Select-String -Path build\export.log -Pattern '^export: end' -Quiet)) { Start-Sleep -Seconds 5; break }
}
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
Select-String -Path build\export.log, build\export-erreurs.log -Pattern 'BUILD |FAILED|error:' | Select-Object -First 25 | ForEach-Object { $_.Line }
if (-not (Test-Path build\corps-galaxie.apk)) { Write-Output 'ARRÊT : APK non produit (voir godot\build\export.log)'; exit 1 }
'{0} : {1:N1} Mo' -f 'APK', ((Get-Item build\corps-galaxie.apk).Length / 1MB)
if ($Installer) {
    # même adb que SideQuest : changer d'adb relance son serveur et le casque redemande alors l'autorisation
    $adb = Join-Path $env:LOCALAPPDATA 'Programs\SideQuest\resources\platform-tools\adb.exe'
    if (-not (Test-Path $adb)) { $adb = 'adb' }
    & $adb install -r build\corps-galaxie.apk
    & $adb shell am start -n io.github.yamgrnt.corpsgalaxie/com.godot.game.GodotApp
}
