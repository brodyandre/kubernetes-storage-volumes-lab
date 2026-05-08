# Nota Didática - `storageClassName: local-path`

Este laboratório usa `storageClassName: local-path`, alinhado ao cluster `k3d-meucluster` (k3s via k3d).

## Verificação rápida

```powershell
kubectl get storageclass
kubectl describe storageclass local-path
```

Resultado esperado no k3d/k3s:

- `StorageClass`: `local-path`
- `Provisioner`: `rancher.io/local-path`

## Se `local-path` não existir

1. Liste as classes disponíveis:

```powershell
kubectl get storageclass
```

2. Escolha uma classe adequada.
3. Edite `pvc-dynamic.yaml`:

```yaml
storageClassName: <nome-da-classe-do-seu-cluster>
```

## Exemplos comuns em outros ambientes

- `hostpath`
- `local-path`
- `csi-hostpath-sc`

Use sempre o nome retornado pelo seu cluster local no Windows 11.
