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
        throw "Não foi possível acessar o cluster Kubernetes atual. Inicie Docker Desktop e o cluster k3d (k3d-meucluster), depois valide o contexto."
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

function Validate-Manifest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest não encontrado: $Path"
    }

    Write-Host "[VALIDATE] $Description" -ForegroundColor Cyan
    kubectl apply --dry-run=server -f $Path | Out-Null
}

function Warn-UnexpectedContext {
    param([string]$Expected = "k3d-meucluster")
    $current = kubectl config current-context
    if ($current -ne $Expected) {
        Write-Warning "Contexto atual '$current' difere do contexto esperado '$Expected'. A validação server-side pode não refletir o ambiente alvo."
    }
}

Assert-Kubectl
Assert-CurrentContext
Assert-Cluster
Warn-UnexpectedContext

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestsRoot = Join-Path $repoRoot "manifests"

Write-Host "[INFO] Contexto atual: $(kubectl config current-context)" -ForegroundColor Yellow
Write-Host "[INFO] Iniciando validação server-side dos manifests..." -ForegroundColor Green

# Validação dos manifests principais (sucesso esperado)
Validate-Manifest -Path (Join-Path $manifestsRoot "01-volume-emptydir/namespace.yaml") -Description "Lab 01 - Namespace"
Validate-Manifest -Path (Join-Path $manifestsRoot "01-volume-emptydir/pod-emptydir.yaml") -Description "Lab 01 - Pod emptyDir"

Validate-Manifest -Path (Join-Path $manifestsRoot "02-hostpath/namespace.yaml") -Description "Lab 02 - Namespace"
Validate-Manifest -Path (Join-Path $manifestsRoot "02-hostpath/pod-hostpath.yaml") -Description "Lab 02 - Pod hostPath"

Validate-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/namespace.yaml") -Description "Lab 03 - Namespace"
Validate-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/persistent-volume.yaml") -Description "Lab 03 - PV"
Validate-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/persistent-volume-claim.yaml") -Description "Lab 03 - PVC"
Validate-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/pod-using-pvc.yaml") -Description "Lab 03 - Pod usando PVC"

Validate-Manifest -Path (Join-Path $manifestsRoot "04-nfs-server/namespace.yaml") -Description "Lab 04 - Namespace"
Validate-Manifest -Path (Join-Path $manifestsRoot "04-nfs-server/nfs-server-deployment.yaml") -Description "Lab 04 - NFS Deployment"
Validate-Manifest -Path (Join-Path $manifestsRoot "04-nfs-server/nfs-server-service.yaml") -Description "Lab 04 - NFS Service"

# Lab 05: prioriza arquivo gerado com ClusterIP real; fallback para template manual.
$nfsGeneratedPath = Join-Path $manifestsRoot "05-nfs-volume/persistent-volume-nfs.generated.yaml"
$nfsTemplatePath = Join-Path $manifestsRoot "05-nfs-volume/persistent-volume-nfs.yaml"
if (Test-Path -LiteralPath $nfsGeneratedPath) {
    Validate-Manifest -Path $nfsGeneratedPath -Description "Lab 05 - PV NFS (gerado)"
}
else {
    Write-Host "[WARN] PV NFS gerado não encontrado. Validando template com placeholder (apenas estrutura)." -ForegroundColor Yellow
    Validate-Manifest -Path $nfsTemplatePath -Description "Lab 05 - PV NFS (template)"
}
Validate-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/persistent-volume-claim-nfs.yaml") -Description "Lab 05 - PVC NFS"
Validate-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/deployment-using-nfs-pvc.yaml") -Description "Lab 05 - Deployment NGINX"
Validate-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/service-nginx-nfs.yaml") -Description "Lab 05 - Service NGINX"

Validate-Manifest -Path (Join-Path $manifestsRoot "06-storageclass/pvc-dynamic.yaml") -Description "Lab 06 - PVC dinâmico"
Validate-Manifest -Path (Join-Path $manifestsRoot "06-storageclass/pod-dynamic-pvc.yaml") -Description "Lab 06 - Pod dinâmico"

Validate-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/namespace.yaml") -Description "Lab 07 - Namespace quota"
Validate-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/limitrange-storage.yaml") -Description "Lab 07 - LimitRange"
Validate-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/resourcequota-storage.yaml") -Description "Lab 07 - ResourceQuota"
Validate-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/pvc-valid.yaml") -Description "Lab 07 - PVC válido"
Validate-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/pvc-quota-01.yaml") -Description "Lab 07 - PVC quota 01"
Validate-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/pvc-quota-02.yaml") -Description "Lab 07 - PVC quota 02"

Validate-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/namespace.yaml") -Description "Lab 08 - Namespace"
Validate-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/configmap-app.yaml") -Description "Lab 08 - ConfigMap"
Validate-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/secret-app.yaml") -Description "Lab 08 - Secret"
Validate-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/pod-configmap-volume.yaml") -Description "Lab 08 - Pod ConfigMap"
Validate-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/pod-secret-volume.yaml") -Description "Lab 08 - Pod Secret"

Write-Host ""
Write-Host "[INFO] Manifests de erro controlado não entram na validação de sucesso:" -ForegroundColor Yellow
Write-Host " - manifests/07-limitrange-resourcequota/pvc-invalid.yaml" -ForegroundColor Yellow
Write-Host " - manifests/07-limitrange-resourcequota/pvc-quota-exceed.yaml" -ForegroundColor Yellow
Write-Host ""
Write-Host "[OK] Validação concluída." -ForegroundColor Green
