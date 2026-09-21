# Запуск OpenClaw Gateway с прогревом модели
# Прогрев нужен, потому что холодная загрузка qwen3:8b в VRAM/RAM
# занимает больше 90 секунд, и `openclaw gateway start` успевает
# отвалиться по таймауту /healthz, хотя Gateway потом поднимается сам.

Write-Host "[1/3] Прогреваю Ollama (qwen3:8b)..." -ForegroundColor Cyan
$warm = @{
    model    = "qwen3:8b"
    messages = @(@{ role = "user"; content = "ping" })
    stream   = $false
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/chat" `
        -Method POST -Body $warm -ContentType "application/json" `
        -TimeoutSec 600 | Out-Null
    Write-Host "      модель загружена" -ForegroundColor Green
} catch {
    Write-Host "      Ollama недоступна: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "[2/3] Запускаю Gateway..." -ForegroundColor Cyan
openclaw gateway start

Write-Host "[3/3] Проверяю готовность..." -ForegroundColor Cyan
for ($i = 1; $i -le 30; $i++) {
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:18789/readyz" -TimeoutSec 5
        if ($r.ready) {
            Write-Host "      readyz OK (uptime $([math]::Round($r.uptimeMs/1000))s)" -ForegroundColor Green
            break
        }
    } catch { }
    Start-Sleep -Seconds 3
}

Write-Host ""
openclaw channels status --probe
