$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Verifica se kubectl está disponível no PATH.
function Assert-Kubectl {
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl não encontrado no PATH do Windows."
    }
}

# Verifica se o cluster Kubernetes responde.
function Assert-Cluster {
    try {
        kubectl get nodes | Out-Null
    }
    catch {
        throw "Não foi possível acessar o cluster Kubernetes atual. Verifique Docker Desktop/k3d (k3d-meucluster) e contexto do kubectl."
    }
}

# Verifica se existe contexto ativo no kubectl.
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

function Apply-Manifest {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest não encontrado: $Path"
    }

    Write-Host "[APPLY] $Description" -ForegroundColor Cyan
    kubectl apply -f $Path
}

function Wait-DeploymentAvailable {
    param(
        [Parameter(Mandatory = $true)][string]$Namespace,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Timeout = "180s"
    )

    Write-Host "[WAIT] deployment/$Name no namespace $Namespace" -ForegroundColor DarkCyan
    kubectl wait --for=condition=Available "deployment/$Name" -n $Namespace --timeout=$Timeout
}

function Assert-LocalPathStorageClass {
    $sc = kubectl get storageclass local-path --ignore-not-found -o name
    if ([string]::IsNullOrWhiteSpace($sc)) {
        throw "StorageClass 'local-path' não encontrada. Este projeto está alinhado ao cluster k3d/k3s (provisioner rancher.io/local-path)."
    }
}

function Warn-UnexpectedContext {
    param([string]$Expected = "k3d-meucluster")
    $current = kubectl config current-context
    if ($current -ne $Expected) {
        Write-Warning "Contexto atual '$current' difere do contexto esperado '$Expected'. Revise antes de aplicar os manifests."
    }
}

Assert-Kubectl
Assert-CurrentContext
Assert-Cluster
Warn-UnexpectedContext

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestsRoot = Join-Path $repoRoot "manifests"
$prepareNfsScript = Join-Path $PSScriptRoot "prepare-nfs-pv.ps1"

if (-not (Test-Path -LiteralPath $prepareNfsScript)) {
    throw "Script auxiliar não encontrado: $prepareNfsScript"
}

Write-Host "[INFO] Contexto atual: $(kubectl config current-context)" -ForegroundColor Yellow
Write-Host "[INFO] Iniciando aplicação dos laboratórios principais..." -ForegroundColor Green

# LAB 01 - emptyDir
Apply-Manifest -Path (Join-Path $manifestsRoot "01-volume-emptydir/namespace.yaml") -Description "Lab 01 - Namespace"
Apply-Manifest -Path (Join-Path $manifestsRoot "01-volume-emptydir/pod-emptydir.yaml") -Description "Lab 01 - Pod emptyDir"

# LAB 02 - hostPath
Apply-Manifest -Path (Join-Path $manifestsRoot "02-hostpath/namespace.yaml") -Description "Lab 02 - Namespace"
Apply-Manifest -Path (Join-Path $manifestsRoot "02-hostpath/pod-hostpath.yaml") -Description "Lab 02 - Pod hostPath"

# LAB 03 - PV/PVC estático
Apply-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/namespace.yaml") -Description "Lab 03 - Namespace"
Apply-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/persistent-volume.yaml") -Description "Lab 03 - PersistentVolume"
Apply-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/persistent-volume-claim.yaml") -Description "Lab 03 - PersistentVolumeClaim"
Apply-Manifest -Path (Join-Path $manifestsRoot "03-pv-pvc/pod-using-pvc.yaml") -Description "Lab 03 - Pod usando PVC"

# LAB 04 - Servidor NFS
Apply-Manifest -Path (Join-Path $manifestsRoot "04-nfs-server/namespace.yaml") -Description "Lab 04 - Namespace"
Apply-Manifest -Path (Join-Path $manifestsRoot "04-nfs-server/nfs-server-deployment.yaml") -Description "Lab 04 - Deployment NFS Server"
Apply-Manifest -Path (Join-Path $manifestsRoot "04-nfs-server/nfs-server-service.yaml") -Description "Lab 04 - Service NFS Server"
Wait-DeploymentAvailable -Namespace "storage-lab" -Name "nfs-server" -Timeout "240s"

# LAB 05 - PV/PVC com NFS
Write-Host "[INFO] Gerando manifest de PV NFS com ClusterIP automático..." -ForegroundColor Cyan
& $prepareNfsScript
Apply-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/persistent-volume-nfs.generated.yaml") -Description "Lab 05 - PersistentVolume NFS (gerado)"
Apply-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/persistent-volume-claim-nfs.yaml") -Description "Lab 05 - PersistentVolumeClaim NFS"
Apply-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/deployment-using-nfs-pvc.yaml") -Description "Lab 05 - Deployment NGINX"
Apply-Manifest -Path (Join-Path $manifestsRoot "05-nfs-volume/service-nginx-nfs.yaml") -Description "Lab 05 - Service NGINX"

# LAB 06 - StorageClass / provisionamento dinâmico
Assert-LocalPathStorageClass
Apply-Manifest -Path (Join-Path $manifestsRoot "06-storageclass/pvc-dynamic.yaml") -Description "Lab 06 - PVC dinâmico (storageClassName=local-path)"
Apply-Manifest -Path (Join-Path $manifestsRoot "06-storageclass/pod-dynamic-pvc.yaml") -Description "Lab 06 - Pod usando PVC dinâmico"

# LAB 07 - Limites e quota (sem aplicar manifests de falha proposital)
Apply-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/namespace.yaml") -Description "Lab 07 - Namespace quota"
Apply-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/limitrange-storage.yaml") -Description "Lab 07 - LimitRange"
Apply-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/resourcequota-storage.yaml") -Description "Lab 07 - ResourceQuota"
Apply-Manifest -Path (Join-Path $manifestsRoot "07-limitrange-resourcequota/pvc-valid.yaml") -Description "Lab 07 - PVC válido"

# LAB 08 - ConfigMap e Secret como volume
Apply-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/namespace.yaml") -Description "Lab 08 - Namespace"
Apply-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/configmap-app.yaml") -Description "Lab 08 - ConfigMap"
Apply-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/pod-configmap-volume.yaml") -Description "Lab 08 - Pod ConfigMap Volume"
Apply-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/secret-app.yaml") -Description "Lab 08 - Secret"
Apply-Manifest -Path (Join-Path $manifestsRoot "08-configmap-secret-volume/pod-secret-volume.yaml") -Description "Lab 08 - Pod Secret Volume"

Write-Host ""
Write-Host "[INFO] Manifests de falha proposital NÃO foram aplicados automaticamente:" -ForegroundColor Yellow
Write-Host " - manifests/07-limitrange-resourcequota/pvc-invalid.yaml" -ForegroundColor Yellow
Write-Host " - manifests/07-limitrange-resourcequota/pvc-quota-exceed.yaml" -ForegroundColor Yellow
Write-Host ""
Write-Host "[OK] Aplicação concluída com sucesso." -ForegroundColor Green
Write-Host "Próximo passo: .\scripts\check-resources.ps1" -ForegroundColor Green
