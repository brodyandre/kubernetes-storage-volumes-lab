$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Verifica se kubectl está disponível no PATH.
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

function Remove-NamespaceSafe {
    param([Parameter(Mandatory = $true)][string]$Name)
    Write-Host "[DELETE] Namespace $Name" -ForegroundColor Cyan
    kubectl delete namespace $Name --ignore-not-found
}

function Remove-LocalFileSafe {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
        Write-Host "[DELETE] Arquivo local removido: $Path" -ForegroundColor DarkCyan
    }
}

function Warn-UnexpectedContext {
    param([string]$Expected = "k3d-meucluster")
    $current = kubectl config current-context
    if ($current -ne $Expected) {
        Write-Warning "Contexto atual '$current' difere do contexto esperado '$Expected'. A limpeza pode atingir outro cluster."
    }
}

Assert-Kubectl
Assert-CurrentContext
Assert-Cluster
Warn-UnexpectedContext

Write-Host "[INFO] Iniciando limpeza dos recursos do projeto..." -ForegroundColor Green

# Namespaces atuais do projeto.
$projectNamespaces = @(
    "storage-lab",
    "storage-lab-quota",
    "storage-lab-config"
)

# Namespaces legados (compatibilidade com versões anteriores dos manifests).
$legacyNamespaces = @(
    "storage-lab-01",
    "storage-lab-02",
    "storage-lab-03",
    "storage-lab-06",
    "storage-lab-07",
    "storage-lab-08",
    "nfs-lab",
    "nfs-app"
)

foreach ($ns in ($projectNamespaces + $legacyNamespaces)) {
    Remove-NamespaceSafe -Name $ns
}

Write-Host "[INFO] Removendo PersistentVolumes conhecidos do projeto..." -ForegroundColor Cyan

# PVs estáticos conhecidos do laboratório.
$knownProjectPvs = @(
    "pv-hostpath-demo",
    "pv-nfs-demo",
    "pv-hostpath-lab",
    "pv-nfs-lab"
)

foreach ($pv in $knownProjectPvs) {
    kubectl delete pv $pv --ignore-not-found
}

# Remove PVs dinâmicos vinculados aos namespaces do projeto.
# Isso evita deixar volumes órfãos após remover namespaces.
$pvData = kubectl get pv -o json | ConvertFrom-Json
$namespacesToMatch = $projectNamespaces + $legacyNamespaces
$pvsBoundToProjectNamespaces = @()

foreach ($item in $pvData.items) {
    $claimRef = $item.spec.claimRef
    if ($null -ne $claimRef -and $namespacesToMatch -contains $claimRef.namespace) {
        $pvsBoundToProjectNamespaces += $item.metadata.name
    }
}

if ($pvsBoundToProjectNamespaces.Count -gt 0) {
    Write-Host "[INFO] Removendo PVs vinculados aos namespaces do projeto..." -ForegroundColor Cyan
    foreach ($pvName in ($pvsBoundToProjectNamespaces | Sort-Object -Unique)) {
        kubectl delete pv $pvName --ignore-not-found
    }
}
else {
    Write-Host "[INFO] Nenhum PV adicional vinculado ao projeto foi encontrado." -ForegroundColor DarkGray
}

# Remove arquivo gerado do PV NFS para evitar reuso acidental em outro cluster.
$repoRoot = Split-Path -Parent $PSScriptRoot
$generatedNfsPv = Join-Path $repoRoot "manifests/05-nfs-volume/persistent-volume-nfs.generated.yaml"
Remove-LocalFileSafe -Path $generatedNfsPv

Write-Host "[OK] Cleanup concluído." -ForegroundColor Green
