# Laboratório 03 - PersistentVolume e PersistentVolumeClaim (estático)

## Objetivo

Demonstrar provisionamento estático com `PersistentVolume` (`PV`) e consumo por `PersistentVolumeClaim` (`PVC`).

## Arquivos

- `namespace.yaml`
- `persistent-volume.yaml`
- `persistent-volume-claim.yaml`
- `pod-using-pvc.yaml`

## Conceitos-chave

| Conceito | Aplicação neste laboratório |
|---|---|
| `PersistentVolume` | `pv-hostpath-demo` com 1Gi |
| `PersistentVolumeClaim` | `pvc-hostpath-demo` solicitando 500Mi |
| `storageClassName` | `manual` para binding estático |
| `AccessMode` | `ReadWriteOnce` |

## Observação importante (Windows 11)

O `hostPath` configurado no PV (`/tmp/k8s-pv-demo`) está no nó Linux interno do cluster local, não no filesystem nativo do Windows.

## Arquitetura lógica

```mermaid
flowchart LR
  A[Pod pod-pvc-demo] --> B[PVC pvc-hostpath-demo]
  B --> C[PV pv-hostpath-demo]
  C --> D[/tmp/k8s-pv-demo no nó Linux]
```

## Execução no PowerShell

```powershell
cd .\manifests\03-pv-pvc
kubectl apply -f .
```

## Validação

```powershell
kubectl get pv
kubectl get pvc -n storage-lab
kubectl describe pv pv-hostpath-demo
kubectl describe pvc pvc-hostpath-demo -n storage-lab
kubectl exec -n storage-lab pod-pvc-demo -- cat /data/message.txt
```

Teste de persistência:

```powershell
kubectl delete pod pod-pvc-demo -n storage-lab
kubectl apply -f pod-using-pvc.yaml
kubectl exec -n storage-lab pod-pvc-demo -- cat /data/message.txt
```

## Limpeza

```powershell
kubectl delete -f .
```

## Troubleshooting

- PVC em `Pending`: valide compatibilidade de `storageClassName`, tamanho e `accessModes`.
- Pod pendente: confirme se o PVC está `Bound`.
- Conteúdo não persiste: garanta que você recriou apenas o Pod, não o PVC/PV.

## Evidências recomendadas

- `kubectl get pv`
- `kubectl get pvc -n storage-lab`
- `kubectl describe pvc pvc-hostpath-demo -n storage-lab`
- leitura de `/data/message.txt` antes e após recriar o Pod
