# CHECKLIST de Publicação - Kubernetes Storage Volumes Lab

Checklist para validar se o projeto está pronto para publicação no GitHub, considerando o ambiente local com **Windows 11 + Docker Desktop + k3d + kubectl**.

## Validação geral

| Status | Item | Comando ou arquivo | Resultado esperado |
|---|---|---|---|
| ⬜ | Docker funcionando | `docker version` | Cliente e servidor Docker respondem sem erro |
| ⬜ | Cluster k3d ativo | `k3d cluster list` | Cluster `k3d-meucluster` listado como ativo |
| ⬜ | `kubectl` conectado ao cluster | `kubectl config current-context` | Contexto atual aponta para `k3d-meucluster` |
| ⬜ | Nodes prontos | `kubectl get nodes` | Nodes em estado `Ready` |
| ⬜ | StorageClass `local-path` disponível | `kubectl get storageclass` | Classe `local-path` aparece na lista |
| ⬜ | Manifests validados localmente | `kubectl apply --dry-run=client -f manifests/01-volume-emptydir` | Validação client-side sem erro |
| ⬜ | Manifests validados no servidor | `kubectl apply --dry-run=server -f manifests/01-volume-emptydir` | Validação server-side sem erro |
| ⬜ | Laboratório `emptyDir` validado | `kubectl logs -n storage-lab pod/emptydir-demo -c reader` | Leitura contínua do arquivo compartilhado em `/data/log.txt` |
| ⬜ | Laboratório `hostPath` validado | `kubectl describe pod hostpath-demo -n storage-lab` | Pod com volume `hostPath` montado corretamente |
| ⬜ | Laboratório PV/PVC validado | `kubectl get pv; kubectl get pvc -n storage-lab` | `pv-hostpath-demo` e `pvc-hostpath-demo` com status consistente (`Bound`) |
| ⬜ | Laboratório StorageClass validado | `kubectl describe storageclass local-path` | Provisioner `rancher.io/local-path` visível |
| ⬜ | Laboratório ConfigMap como volume validado | `kubectl exec -n storage-lab-config pod-configmap-volume-demo -- ls -l /etc/config` | Arquivos do ConfigMap montados no container |
| ⬜ | Laboratório Secret como volume validado | `kubectl exec -n storage-lab-config pod-secret-volume-demo -- ls -l /etc/secret` | Arquivos do Secret montados no container |
| ⬜ | README revisado | `README.md` | Instruções claras, alinhadas ao k3d/local-path e sem dependência obrigatória de WSL2 |
| ⬜ | Scripts PowerShell revisados | `scripts/apply-all.ps1`, `scripts/check-resources.ps1`, `scripts/cleanup-all.ps1`, `scripts/prepare-nfs-pv.ps1` | Scripts executáveis, com mensagens claras e fluxo seguro |
| ⬜ | `.gitignore` revisado | `.gitignore` | Ignora temporários, logs, cache, credenciais e arquivo NFS gerado localmente |
| ⬜ | Nenhum dado sensível versionado | `git grep -n -E "(AKIA|BEGIN PRIVATE KEY|password\\s*=|secret\\s*=)"` | Nenhum segredo real encontrado (somente exemplos didáticos permitidos) |
| ⬜ | Repositório pronto para GitHub | `git status` | Alterações revisadas e branch pronta para commit/push |

## Checklist de publicação

```powershell
git status
git add .
git commit -m "docs: create kubernetes storage volumes lab"
git branch -M main
git remote -v
git push -u origin main
```
