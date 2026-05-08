# 03 - PersistentVolume (PV) e PersistentVolumeClaim (PVC)

## 1. Explicação conceitual

No Kubernetes, `PersistentVolume` e `PersistentVolumeClaim` separam a infraestrutura de storage do consumo pela aplicação:

- `PV` representa um volume real disponível no cluster;
- `PVC` representa o pedido de armazenamento feito por um Pod;
- o Pod monta o `PVC`, sem precisar conhecer detalhes da implementação do volume.

Neste laboratório, o PV usa `hostPath` para ambiente local.
Ambiente alvo: cluster `k3d-meucluster`.

### Tabela rápida

| Item | Exemplo deste lab |
|---|---|
| PV | `pv-hostpath-demo` |
| PVC | `pvc-hostpath-demo` |
| Pod | `pod-pvc-demo` |
| StorageClass | `manual` |
| AccessMode | `ReadWriteOnce` |

## 2. Quando usar

- quando você quer controlar capacidade, modo de acesso e política de retenção;
- em ambientes onde o time de plataforma cria volumes e os times de aplicação apenas consomem via PVC;
- para estudar o modelo clássico de provisionamento estático.

## 3. Quando evitar

- quando seu cluster já tem `StorageClass` com provisionamento dinâmico e não há necessidade de PV manual;
- quando o backend escolhido é `hostPath` em produção (não recomendado);
- quando a aplicação não precisa de persistência.

## 4. Exemplo prático

Arquivos do lab `manifests/03-pv-pvc`:

- `persistent-volume.yaml` cria `pv-hostpath-demo` (1Gi, `ReadWriteOnce`, `storageClassName: manual`);
- `persistent-volume-claim.yaml` cria `pvc-hostpath-demo` solicitando 500Mi;
- `pod-using-pvc.yaml` monta o PVC em `/data` e grava `message.txt`.

Trecho didático:

```yaml
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 500Mi
```

## 5. Diagrama Mermaid

```mermaid
flowchart LR
  A[Pod pod-pvc-demo] --> B[PVC pvc-hostpath-demo]
  B --> C[PV pv-hostpath-demo]
  C --> D[/tmp/k8s-pv-demo no nó Linux]
```

Observação Windows 11: o caminho `/tmp/k8s-pv-demo` está no nó Linux interno do cluster local (k3d/k3s), não no disco `C:\`.

## 6. Comandos kubectl úteis (PowerShell)

```powershell
# Aplicar todo o laboratório
kubectl apply -f .\manifests\03-pv-pvc

# Verificar vínculo PV/PVC
kubectl get pv
kubectl get pvc -n storage-lab
kubectl describe pv pv-hostpath-demo
kubectl describe pvc pvc-hostpath-demo -n storage-lab

# Verificar Pod e conteúdo do volume
kubectl get pods -n storage-lab
kubectl exec -n storage-lab pod-pvc-demo -- cat /data/message.txt

# Teste de persistência: apagar e recriar somente o Pod
kubectl delete pod pod-pvc-demo -n storage-lab
kubectl apply -f .\manifests\03-pv-pvc\pod-using-pvc.yaml
kubectl exec -n storage-lab pod-pvc-demo -- cat /data/message.txt
```

## 7. Erros comuns e como resolver

- **PVC em `Pending` por incompatibilidade de `storageClassName`**  
  PV e PVC precisam ter classes compatíveis (`manual` neste lab).

- **PVC em `Pending` por tamanho**  
  O pedido do PVC não pode exceder a capacidade do PV compatível.

- **`AccessModes` incompatíveis**  
  PVC e PV devem ter modos de acesso compatíveis (`ReadWriteOnce` neste lab).

- **Pod não inicia por PVC não vinculado**  
  Enquanto o PVC não estiver `Bound`, o Pod pode ficar pendente.

- **Confusão com hostPath no Windows**  
  O dado persiste no nó Linux do cluster local; não espere ver diretamente em `C:\`.

## 8. Resumo final

PV/PVC é a base da persistência em Kubernetes. Você declara o volume (PV), solicita com regra clara (PVC) e consome no Pod. Esse padrão melhora organização, governança e portabilidade entre aplicações.
