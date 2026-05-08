$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Comando obrigatório não encontrado: $Name"
    }
}

function Get-ClusterState {
    $context = ""
    $hasContext = $false
    $isReachable = $false

    try {
        $ctxRaw = (kubectl config current-context 2>$null)
        $context = if ($null -eq $ctxRaw) { "" } else { [string]$ctxRaw }
        $context = $context.Trim()
        $hasContext = -not [string]::IsNullOrWhiteSpace($context)
    }
    catch {
        $hasContext = $false
    }

    if ($hasContext) {
        try {
            $ready = kubectl get --raw='/readyz' 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($ready | Out-String))) {
                $isReachable = $true
            }
        }
        catch {
            $isReachable = $false
        }
    }

    [pscustomobject]@{
        Context     = $context
        HasContext  = $hasContext
        IsReachable = $isReachable
        Connected   = ($hasContext -and $isReachable)
    }
}

function Wrap-TextLine {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [int]$MaxChars = 120
    )

    if ([string]::IsNullOrEmpty($Text) -or $Text.Length -le $MaxChars) {
        return @($Text)
    }

    $wrapped = @()
    $remaining = $Text

    while ($remaining.Length -gt $MaxChars) {
        $chunk = $remaining.Substring(0, $MaxChars)
        $breakAt = $chunk.LastIndexOf(" ")
        if ($breakAt -lt 16) {
            $breakAt = $MaxChars
        }

        $wrapped += $remaining.Substring(0, $breakAt).TrimEnd()
        if ($remaining.Length -le $breakAt) {
            $remaining = ""
        }
        else {
            $remaining = $remaining.Substring($breakAt).TrimStart()
        }
    }

    if ($remaining.Length -gt 0) {
        $wrapped += $remaining
    }

    return $wrapped
}

function Wrap-TextLines {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][AllowEmptyString()][string[]]$Lines,
        [int]$MaxChars = 120
    )

    $result = @()
    foreach ($line in $Lines) {
        $result += Wrap-TextLine -Text $line -MaxChars $MaxChars
    }
    return $result
}

function Normalize-CommandOutput {
    param([Parameter(Mandatory = $true)][string]$RawOutput)

    $lines = $RawOutput -split "`r?`n"
    $filtered = @()
    $memcacheCount = 0

    foreach ($line in $lines) {
        if ($line -match "memcache\.go:\d+") {
            $memcacheCount++
            continue
        }
        $filtered += $line
    }

    if ($memcacheCount -gt 0) {
        $filtered = @(
            "[Aviso] Saída resumida para legibilidade: $memcacheCount linha(s) de 'memcache.go' ocultadas.",
            ""
        ) + $filtered
    }

    return (($filtered | Where-Object { $_ -ne $null }) -join "`n")
}

function Test-OutputRegex {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return ($Text -match $Pattern)
}

function New-TextScreenshot {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Command,
        [string]$DisplayCommand = $Command,
        [Parameter(Mandatory = $true)][object]$Body,
        [Parameter(Mandatory = $true)][string]$StatusLabel,
        [Parameter(Mandatory = $true)][ValidateSet("success", "error", "warning", "info", "neutral")][string]$StatusKind
    )

    Add-Type -AssemblyName System.Drawing

    # Fontes maiores para melhorar leitura no GitHub.
    $font = New-Object System.Drawing.Font("Consolas", 18)
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
    $metaFont = New-Object System.Drawing.Font("Segoe UI", 16)

    $status = $StatusLabel
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $header = @(
        "Kubernetes Storage Volumes Lab - Evidência",
        "Título: $Title",
        "Status: $status",
        "Comando: $DisplayCommand",
        "Data/Hora: $timestamp"
    )

    $bodyText = if ($Body -is [System.Array]) {
        ($Body | Out-String)
    }
    else {
        [string]$Body
    }

    $headerWrapped = Wrap-TextLines -Lines $header -MaxChars 95
    $bodyLines = Wrap-TextLines -Lines ($bodyText -split "`r?`n") -MaxChars 120

    $lines = @()
    $lines += $headerWrapped
    $lines += ""
    $lines += "Saída:"
    $lines += "------------------------------------------------------------"
    $lines += $bodyLines

    $dummyBitmap = New-Object System.Drawing.Bitmap 1, 1
    $graphics = [System.Drawing.Graphics]::FromImage($dummyBitmap)
    $graphics.PageUnit = [System.Drawing.GraphicsUnit]::Pixel

    $maxWidth = 1700
    foreach ($line in $lines) {
        $size = $graphics.MeasureString($line, $font)
        $candidate = [int]([Math]::Ceiling($size.Width)) + 40
        if ($candidate -gt $maxWidth) { $maxWidth = $candidate }
    }
    if ($maxWidth -gt 2200) { $maxWidth = 2200 }

    $lineHeight = [int]([Math]::Ceiling($font.GetHeight($graphics))) + 10
    $titleHeight = 60
    $metaHeight = 34
    $height = 30 + $titleHeight + ($metaHeight * ($headerWrapped.Count - 1)) + 20 + ($lineHeight * (($lines.Count - $headerWrapped.Count)))
    if ($height -lt 1000) { $height = 1000 }
    if ($height -gt 6000) { $height = 6000 }

    $bitmap = New-Object System.Drawing.Bitmap $maxWidth, $height
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    # Tema escuro para melhor contraste no portfólio.
    $g.Clear([System.Drawing.Color]::FromArgb(11, 15, 25))
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

    $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(248, 250, 252))
    $metaBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(203, 213, 225))
    $bodyBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(241, 245, 249))
    $statusColor = switch ($StatusKind) {
        "success" { [System.Drawing.Color]::FromArgb(34, 197, 94) }
        "error" { [System.Drawing.Color]::FromArgb(239, 68, 68) }
        "warning" { [System.Drawing.Color]::FromArgb(250, 204, 21) }
        "info" { [System.Drawing.Color]::FromArgb(56, 189, 248) }
        default { [System.Drawing.Color]::FromArgb(148, 163, 184) }
    }
    $statusBrush = New-Object System.Drawing.SolidBrush($statusColor)

    $y = 16
    $g.DrawString($headerWrapped[0], $titleFont, $titleBrush, 20, $y)
    $y += $titleHeight

    for ($h = 1; $h -lt $headerWrapped.Count; $h++) {
        $line = $headerWrapped[$h]
        if ($line.StartsWith("Status: ")) {
            $g.DrawString("Status: ", $metaFont, $metaBrush, 20, $y)
            $g.DrawString($status, $metaFont, $statusBrush, 92, $y)
        }
        else {
            $g.DrawString($line, $metaFont, $metaBrush, 20, $y)
        }
        $y += $metaHeight
    }
    $y += 8

    for ($i = $headerWrapped.Count; $i -lt $lines.Count; $i++) {
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
        [Parameter(Mandatory = $true)][string]$Command,
        [string]$DisplayCommand = $Command,
        [ValidateSet("success", "expected-error", "expected-warning", "info")][string]$ExpectedOutcome = "success",
        [bool]$RequiresCluster = $true,
        [Parameter(Mandatory = $true)][psobject]$ClusterState
    )

    Write-Host "[CAPTURE] $FileName - $Title" -ForegroundColor Cyan

    $output = ""
    $ok = $false
    $statusLabel = "FALHA"
    $statusKind = "error"

    if ($RequiresCluster -and -not $ClusterState.Connected) {
        $contextLine = if ($ClusterState.HasContext) {
            "Contexto atual: '$($ClusterState.Context)' (API indisponível)."
        }
        else {
            "Nenhum contexto Kubernetes ativo encontrado."
        }

        $output = @(
            "Comando não executado para evitar evidência incoerente.",
            $contextLine,
            "Conecte o cluster e regenere os prints:",
            "kubectl config use-context k3d-meucluster",
            ".\scripts\generate-screenshots.ps1"
        ) -join "`n"

        $statusLabel = "NÃO EXECUTADO"
        $statusKind = "neutral"
    }
    else {
        try {
            $outputObj = Invoke-Expression "$Command 2>&1"
            $output = ($outputObj | Out-String)
            $ok = $?
        }
        catch {
            $ok = $false
            $errorText = $_.Exception.Message
            $output = "Erro ao executar comando.`n$errorText`n`nDetalhes:`n$($_ | Out-String)"
        }

        switch ($ExpectedOutcome) {
            "success" {
                $statusLabel = if ($ok) { "SUCESSO" } else { "FALHA" }
                $statusKind = if ($ok) { "success" } else { "error" }
            }
            "expected-error" {
                # Ajuste fino será feito após normalização da saída.
                $statusLabel = if ($ok) { "ATENÇÃO" } else { "ERRO CONTROLADO" }
                $statusKind = "warning"
            }
            "expected-warning" {
                # Ajuste fino será feito após normalização da saída.
                $statusLabel = if ($ok) { "SUCESSO" } else { "LIMITAÇÃO DE AMBIENTE" }
                $statusKind = if ($ok) { "success" } else { "warning" }
            }
            "info" {
                $statusLabel = "INFORMATIVO"
                $statusKind = "info"
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        $output = "(sem saída)"
    }

    $normalized = Normalize-CommandOutput -RawOutput $output
    $hasKubernetesError = Test-OutputRegex -Text $normalized -Pattern "(?i)\berror from server\b|\bforbidden\b|\binvalid\b|\bfailed\b"
    $hasNfsLimitation = Test-OutputRegex -Text $normalized -Pattern "(?i)failedmount|connection refused|not supported|mountvolume\.setup failed|containercreating"

    if ($ExpectedOutcome -eq "expected-error") {
        if ($hasKubernetesError) {
            $statusLabel = "ERRO CONTROLADO"
            $statusKind = "warning"
        }
        elseif ($ok) {
            $statusLabel = "ATENÇÃO"
            $statusKind = "warning"
            $normalized = "Este laboratório esperava erro controlado, mas o comando retornou sucesso.`n`n$normalized"
        }
    }
    elseif ($ExpectedOutcome -eq "expected-warning") {
        if ($hasNfsLimitation) {
            $statusLabel = "LIMITAÇÃO DE AMBIENTE"
            $statusKind = "warning"
            $normalized = @(
                "[Aviso] O comando refletiu limitação conhecida de ambiente local (ex.: suporte NFS no nó do cluster).",
                "Resultado real mantido para documentação técnica:",
                "",
                $normalized
            ) -join "`n"
        }
        elseif ($ok) {
            $statusLabel = "SUCESSO"
            $statusKind = "success"
        }
    }

    New-TextScreenshot -OutputPath $FileName -Title $Title -Command $Command -DisplayCommand $DisplayCommand -Body $normalized -StatusLabel $statusLabel -StatusKind $statusKind
}

Assert-Command -Name kubectl

$repoRoot = Split-Path -Parent $PSScriptRoot
$screenshotsDir = Join-Path $repoRoot "screenshots"
$clusterState = Get-ClusterState

if ($clusterState.Connected) {
    Write-Host "[INFO] Contexto ativo: $($clusterState.Context)" -ForegroundColor Green
}
elseif ($clusterState.HasContext) {
    Write-Host "[WARN] Contexto '$($clusterState.Context)' encontrado, mas API indisponível." -ForegroundColor Yellow
}
else {
    Write-Host "[WARN] Nenhum contexto Kubernetes ativo. Prints de cluster serão marcados como NÃO EXECUTADO." -ForegroundColor Yellow
}

$captures = @(
    @{ File = "01-kubectl-get-nodes.png"; Title = "kubectl get nodes"; Command = "kubectl get nodes" },
    @{ File = "02-kubectl-get-pv.png"; Title = "kubectl get pv"; Command = "kubectl get pv" },
    @{ File = "03-kubectl-get-pvc-all.png"; Title = "kubectl get pvc -A"; Command = "kubectl get pvc -A" },
    @{ File = "04-kubectl-get-storageclass.png"; Title = "kubectl get storageclass"; Command = "kubectl get storageclass" },
    @{ File = "05-describe-pvc-success.png"; Title = "describe pvc (sucesso esperado)"; Command = "kubectl describe pvc pvc-hostpath-demo -n storage-lab" },
    @{ File = "06-describe-pvc-error.png"; Title = "pvc inválido (erro controlado)"; ExpectedOutcome = "expected-error"; Command = "kubectl apply -f manifests/07-limitrange-resourcequota/pvc-invalid.yaml" },
    @{ File = "07-emptydir-logs.png"; Title = "logs emptyDir writer/reader"; Command = "kubectl logs -n storage-lab pod/emptydir-demo -c writer --tail=25; echo '-----'; kubectl logs -n storage-lab pod/emptydir-demo -c reader --tail=25" },
    @{ File = "08-hostpath-http.png"; Title = "hostPath via NGINX"; Command = "kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/index.html" },
    @{ File = "09-nfs-shared-content.png"; Title = "NFS compartilhado entre réplicas"; ExpectedOutcome = "expected-warning"; Command = "kubectl get pods -n storage-lab -l app=nginx-nfs-demo; echo '-----'; kubectl describe pod -n storage-lab -l app=nginx-nfs-demo | Select-String -Pattern 'FailedMount|Connection refused|Not supported|MountVolume.SetUp failed' -Context 0,1" },
    @{ File = "10-configmap-volume.png"; Title = "ConfigMap montado em volume"; Command = "kubectl exec -n storage-lab-config pod-configmap-volume-demo -- ls -l /etc/config; echo '-----'; kubectl exec -n storage-lab-config pod-configmap-volume-demo -- cat /etc/config/app.properties" },
    @{ File = "11-secret-volume.png"; Title = "Secret montado em volume"; Command = "kubectl exec -n storage-lab-config pod-secret-volume-demo -- ls -l /etc/secret; echo '-----'; kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/username; echo '-----'; kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/password" },
    @{ File = "12-scripts-apply-check-cleanup.png"; Title = "execução scripts PowerShell"; RequiresCluster = $false; DisplayCommand = "scripts PowerShell (apply/check/cleanup)"; Command = "Write-Output 'Comando sugerido para evidência:'; Write-Output ''; Write-Output 'Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass'; Write-Output '.\\scripts\\apply-all.ps1'; Write-Output '.\\scripts\\check-resources.ps1'; Write-Output '.\\scripts\\cleanup-all.ps1'; Write-Output ''; Write-Output 'No CMD:'; Write-Output 'powershell -ExecutionPolicy Bypass -File .\\scripts\\check-resources.ps1'" }
)

Write-Host "[INFO] Gerando screenshots em: $screenshotsDir" -ForegroundColor Yellow
foreach ($c in $captures) {
    $path = Join-Path $screenshotsDir $c.File
    $displayCommand = if ($c.ContainsKey("DisplayCommand")) { [string]$c.DisplayCommand } else { [string]$c.Command }
    $expectedOutcome = if ($c.ContainsKey("ExpectedOutcome")) { [string]$c.ExpectedOutcome } else { "success" }
    $requiresCluster = if ($c.ContainsKey("RequiresCluster")) { [bool]$c.RequiresCluster } else { $true }

    Capture-Screenshot `
        -FileName $path `
        -Title $c.Title `
        -Command $c.Command `
        -DisplayCommand $displayCommand `
        -ExpectedOutcome $expectedOutcome `
        -RequiresCluster $requiresCluster `
        -ClusterState $clusterState
}

Write-Host "[OK] Capturas finalizadas." -ForegroundColor Green
Write-Host "Arquivos gerados em .\\screenshots" -ForegroundColor Green
