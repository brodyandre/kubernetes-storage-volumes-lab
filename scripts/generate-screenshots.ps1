$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Comando obrigatório não encontrado: $Name"
    }
}

function New-TextScreenshot {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][object]$Body,
        [Parameter(Mandatory = $true)][bool]$Succeeded
    )

    Add-Type -AssemblyName System.Drawing

    $font = New-Object System.Drawing.Font("Consolas", 12)
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $metaFont = New-Object System.Drawing.Font("Segoe UI", 10)

    $status = if ($Succeeded) { "SUCESSO" } else { "FALHA" }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = @(
        "Kubernetes Storage Volumes Lab - Evidência",
        "Título: $Title",
        "Status: $status",
        "Comando: $Command",
        "Data/Hora: $timestamp"
    )

    $bodyText = if ($Body -is [System.Array]) {
        ($Body | Out-String)
    }
    else {
        [string]$Body
    }

    $lines = @()
    $lines += $header
    $lines += ""
    $lines += "Saída:"
    $lines += "------------------------------------------------------------"
    $lines += ($bodyText -split "`r?`n")

    $dummyBitmap = New-Object System.Drawing.Bitmap 1, 1
    $graphics = [System.Drawing.Graphics]::FromImage($dummyBitmap)
    $graphics.PageUnit = [System.Drawing.GraphicsUnit]::Pixel

    $maxWidth = 1280
    foreach ($line in $lines) {
        $size = $graphics.MeasureString($line, $font)
        $candidate = [int]([Math]::Ceiling($size.Width)) + 40
        if ($candidate -gt $maxWidth) { $maxWidth = $candidate }
    }

    $lineHeight = [int]([Math]::Ceiling($font.GetHeight($graphics))) + 4
    $titleHeight = 34
    $metaHeight = 20
    $height = 30 + $titleHeight + ($metaHeight * 4) + 20 + ($lineHeight * ($lines.Count - 5))
    if ($height -lt 720) { $height = 720 }
    if ($height -gt 6000) { $height = 6000 }

    $bitmap = New-Object System.Drawing.Bitmap $maxWidth, $height
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.Clear([System.Drawing.Color]::FromArgb(248, 249, 251))
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(33, 37, 41))
    $metaBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(73, 80, 87))
    $bodyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(17, 24, 39))
    $statusColor = if ($Succeeded) {
        [System.Drawing.Color]::FromArgb(33, 120, 58)
    }
    else {
        [System.Drawing.Color]::FromArgb(185, 28, 28)
    }
    $statusBrush = New-Object System.Drawing.SolidBrush($statusColor)

    $y = 16
    $g.DrawString($header[0], $titleFont, $titleBrush, 20, $y)
    $y += $titleHeight

    $g.DrawString($header[1], $metaFont, $metaBrush, 20, $y); $y += $metaHeight
    $g.DrawString("Status: ", $metaFont, $metaBrush, 20, $y)
    $g.DrawString($status, $metaFont, $statusBrush, 70, $y); $y += $metaHeight
    $g.DrawString($header[3], $metaFont, $metaBrush, 20, $y); $y += $metaHeight
    $g.DrawString($header[4], $metaFont, $metaBrush, 20, $y); $y += $metaHeight + 8

    for ($i = 5; $i -lt $lines.Count; $i++) {
        if ($y -gt ($height - 30)) { break }
        $g.DrawString($lines[$i], $font, $bodyBrush, 20, $y)
        $y += $lineHeight
    }

    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bitmap.Dispose()
    $graphics.Dispose()
    $dummyBitmap.Dispose()
    $font.Dispose()
    $titleFont.Dispose()
    $metaFont.Dispose()
    $titleBrush.Dispose()
    $metaBrush.Dispose()
    $bodyBrush.Dispose()
    $statusBrush.Dispose()
}

function Capture-Screenshot {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Command
    )

    Write-Host "[CAPTURE] $FileName - $Title" -ForegroundColor Cyan

    $output = ""
    $ok = $true
    try {
        $outputObj = Invoke-Expression "$Command 2>&1"
        $output = ($outputObj | Out-String)
        if ($LASTEXITCODE -ne 0) { $ok = $false }
    }
    catch {
        $ok = $false
        $errorText = $_.Exception.Message
        $output = "Erro ao executar comando.`n$errorText`n`nDetalhes:`n$($_ | Out-String)"
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        $output = "(sem saída)"
    }

    New-TextScreenshot -OutputPath $FileName -Title $Title -Command $Command -Body $output -Succeeded $ok
}

Assert-Command -Name kubectl

$repoRoot = Split-Path -Parent $PSScriptRoot
$screenshotsDir = Join-Path $repoRoot "screenshots"

$captures = @(
    @{ File = "01-kubectl-get-nodes.png"; Title = "kubectl get nodes"; Command = "kubectl get nodes" },
    @{ File = "02-kubectl-get-pv.png"; Title = "kubectl get pv"; Command = "kubectl get pv" },
    @{ File = "03-kubectl-get-pvc-all.png"; Title = "kubectl get pvc -A"; Command = "kubectl get pvc -A" },
    @{ File = "04-kubectl-get-storageclass.png"; Title = "kubectl get storageclass"; Command = "kubectl get storageclass" },
    @{ File = "05-describe-pvc-success.png"; Title = "describe pvc (sucesso esperado)"; Command = "kubectl describe pvc pvc-hostpath-demo -n storage-lab" },
    @{ File = "06-describe-pvc-error.png"; Title = "describe pvc (erro controlado)"; Command = "kubectl describe pvc pvc-invalid -n storage-lab-quota" },
    @{ File = "07-emptydir-logs.png"; Title = "logs emptyDir writer/reader"; Command = "kubectl logs -n storage-lab pod/emptydir-demo -c writer --tail=25; echo '-----'; kubectl logs -n storage-lab pod/emptydir-demo -c reader --tail=25" },
    @{ File = "08-hostpath-http.png"; Title = "hostPath via NGINX"; Command = "kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/index.html" },
    @{ File = "09-nfs-shared-content.png"; Title = "NFS compartilhado entre réplicas"; Command = "kubectl get pods -n storage-lab -l app=nginx-nfs-demo; echo '-----'; kubectl exec -n storage-lab deployment/nginx-nfs-demo -- cat /usr/share/nginx/html/index.html" },
    @{ File = "10-configmap-volume.png"; Title = "ConfigMap montado em volume"; Command = "kubectl exec -n storage-lab-config pod-configmap-volume-demo -- ls -l /etc/config; echo '-----'; kubectl exec -n storage-lab-config pod-configmap-volume-demo -- cat /etc/config/app.properties" },
    @{ File = "11-secret-volume.png"; Title = "Secret montado em volume"; Command = "kubectl exec -n storage-lab-config pod-secret-volume-demo -- ls -l /etc/secret; echo '-----'; kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/username; echo '-----'; kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/password" },
    @{ File = "12-scripts-apply-check-cleanup.png"; Title = "execução scripts PowerShell"; Command = "Write-Output 'Comando sugerido para evidência:'; Write-Output 'Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass'; Write-Output '.\\scripts\\apply-all.ps1'; Write-Output '.\\scripts\\check-resources.ps1'; Write-Output '.\\scripts\\cleanup-all.ps1'" }
)

Write-Host "[INFO] Gerando screenshots em: $screenshotsDir" -ForegroundColor Yellow
foreach ($c in $captures) {
    $path = Join-Path $screenshotsDir $c.File
    Capture-Screenshot -FileName $path -Title $c.Title -Command $c.Command
}

Write-Host "[OK] Capturas finalizadas." -ForegroundColor Green
Write-Host "Arquivos gerados em .\\screenshots" -ForegroundColor Green
