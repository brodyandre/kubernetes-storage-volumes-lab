$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Kubectl {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl não encontrado no PATH do Windows."
    }
}

function Assert-Cluster {
    try {
        kubectl get nodes | Out-Null
    }
    catch {
        throw "Não foi possível acessar o cluster Kubernetes atual. Verifique Docker Desktop/k3d (k3d-meucluster) e contexto do kubectl."
    }
}

function Assert-CurrentContext {
    try {
        $current = (kubectl config current-context).Trim()
    }
    catch {
        throw "Não foi possível ler o contexto atual do kubectl. Configure um contexto Kubernetes ativo."
    }

    if ([string]::IsNullOrWhiteSpace($current)) {
        throw "Nenhum contexto Kubernetes ativo foi encontrado. Configure o contexto e tente novamente."
    }
}

function Warn-UnexpectedContext {
    param([string]$Expected = "k3d-meucluster")
    $current = kubectl config current-context
    if ($current -ne $Expected) {
        Write-Warning "Contexto atual '$current' difere do contexto esperado '$Expected'. O ClusterIP gerado pode ser de outro cluster."
    }
}

Assert-Kubectl
Assert-CurrentContext
Assert-Cluster
Warn-UnexpectedContext

$repoRoot = Split-Path -Parent $PSScriptRoot
$nfsNamespace = "storage-lab"
$nfsServiceName = "nfs-server"

$templatePath = Join-Path $repoRoot "manifests/05-nfs-volume/persistent-volume-nfs.yaml"
$generatedPath = Join-Path $repoRoot "manifests/05-nfs-volume/persistent-volume-nfs.generated.yaml"

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Template não encontrado: $templatePath"
}

Write-Host "[INFO] Lendo ClusterIP do Service $nfsServiceName no namespace $nfsNamespace..." -ForegroundColor Cyan
$nfsIp = (kubectl get svc $nfsServiceName -n $nfsNamespace -o jsonpath="{.spec.clusterIP}").Trim()

if ([string]::IsNullOrWhiteSpace($nfsIp) -or $nfsIp -eq "<none>") {
    throw "Não foi possível obter ClusterIP do Service $nfsServiceName no namespace $nfsNamespace."
}

$template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8

if ($template -notmatch "NFS_SERVER_CLUSTER_IP") {
    throw "Placeholder NFS_SERVER_CLUSTER_IP não encontrado no arquivo template: $templatePath"
}

$generated = $template.Replace("NFS_SERVER_CLUSTER_IP", $nfsIp)
Set-Content -LiteralPath $generatedPath -Value $generated -Encoding UTF8

Write-Host "[OK] Arquivo gerado com sucesso." -ForegroundColor Green
Write-Host "[INFO] IP usado no PV NFS: $nfsIp" -ForegroundColor Yellow
Write-Host "[INFO] Arquivo de saída: manifests/05-nfs-volume/persistent-volume-nfs.generated.yaml" -ForegroundColor Yellow
Write-Host ""
Write-Host "Próximo passo sugerido:" -ForegroundColor Cyan
Write-Host "kubectl apply -f manifests/05-nfs-volume/persistent-volume-nfs.generated.yaml" -ForegroundColor White
