$token = "8881672889:AAH33jbmgtt-jbgHhe7DbjC7AGLEE4Y8FdM"
$chat = "8082708835"
$url = "https://api.telegram.org/bot$token/sendMessage"
$body = "chat_id=$chat&text=Привет! Это тест от компьютера $env:COMPUTERNAME"
Invoke-WebRequest -Uri $url -Method Post -Body $body