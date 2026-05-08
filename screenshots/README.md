# Capturas e Evidências

Esta pasta concentra prints para documentação técnica e portfólio GitHub.

## Geração automática

As evidências podem ser geradas automaticamente com:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\generate-screenshots.ps1
```

Observação:

- se o cluster Kubernetes local não estiver ativo/configurado, os PNGs serão gerados com status de falha na saída do comando;
- após iniciar Docker Desktop e o cluster `k3d-meucluster` e aplicar os laboratórios, execute o script novamente para atualizar os prints com status de sucesso.

## Estrutura sugerida

| Arquivo sugerido | Evidência |
|---|---|
| `01-kubectl-get-nodes.png` | cluster ativo |
| `02-kubectl-get-pv.png` | PVs criados |
| `03-kubectl-get-pvc-all.png` | PVCs em todos namespaces |
| `04-kubectl-get-storageclass.png` | classes disponíveis |
| `05-describe-pvc-success.png` | PVC válido com `Bound` |
| `06-describe-pvc-error.png` | erro controlado (`LimitRange`/`ResourceQuota`) |
| `07-emptydir-logs.png` | writer/reader compartilhando volume |
| `08-hostpath-http.png` | `hostPath` servido pelo NGINX |
| `09-nfs-shared-content.png` | conteúdo compartilhado entre réplicas |
| `10-configmap-volume.png` | arquivos em `/etc/config` |
| `11-secret-volume.png` | arquivos em `/etc/secret` |
| `12-scripts-apply-check-cleanup.png` | execução dos scripts PowerShell |

## Checklist de evidências mínimas

- `kubectl get nodes`
- `kubectl get pv`
- `kubectl get pvc -A`
- `kubectl get storageclass`
- `kubectl describe pvc`
- `kubectl describe pv`
- `kubectl get pods -A`
- teste do `emptyDir`
- teste do `hostPath`
- teste do NFS
- teste do ConfigMap como volume
- teste do Secret como volume
- erro controlado do `LimitRange`
- erro controlado do `ResourceQuota`
- execução de `apply-all.ps1`, `check-resources.ps1` e `cleanup-all.ps1`
