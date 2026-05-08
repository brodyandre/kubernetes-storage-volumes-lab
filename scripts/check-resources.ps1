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

function Show-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Warn-UnexpectedContext {
    param([string]$Expected = "k3d-meucluster")
    $current = kubectl config current-context
    if ($current -ne $Expected) {
        Write-Warning "Contexto atual '$current' difere do contexto esperado '$Expected'."
    }
}

Assert-Kubectl
Assert-CurrentContext
Assert-Cluster
Warn-UnexpectedContext

Show-Section -Title "Contexto atual"
kubectl config current-context

Show-Section -Title "Nodes"
kubectl get nodes

Show-Section -Title "Namespaces"
kubectl get namespaces

Show-Section -Title "Namespaces do projeto"
kubectl get namespaces storage-lab storage-lab-quota storage-lab-config --ignore-not-found

Show-Section -Title "Pods (todos os namespaces)"
kubectl get pods -A

Show-Section -Title "Services (todos os namespaces)"
kubectl get services -A

Show-Section -Title "PersistentVolumes (PV)"
kubectl get pv

Show-Section -Title "PersistentVolumeClaims (PVC)"
kubectl get pvc -A

Show-Section -Title "PVCs por namespace do projeto"
kubectl get pvc -n storage-lab --ignore-not-found
kubectl get pvc -n storage-lab-quota --ignore-not-found
kubectl get pvc -n storage-lab-config --ignore-not-found

Show-Section -Title "StorageClass"
kubectl get storageclass

Show-Section -Title "LimitRange (todos os namespaces)"
kubectl get limitrange -A

Show-Section -Title "ResourceQuota (todos os namespaces)"
kubectl get resourcequota -A

Write-Host ""
Write-Host "[OK] Verificação concluída." -ForegroundColor Green
