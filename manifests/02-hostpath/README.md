# Laboratório 02 - Volume `hostPath`

## Objetivo

Demonstrar montagem de `hostPath` em um Pod NGINX e explicar o comportamento no Kubernetes local executado a partir do Windows 11.

## Arquivos

- `namespace.yaml`
- `pod-hostpath.yaml`
- `hostpath-local-test.md`

## Conceitos-chave

| Conceito | Aplicação neste laboratório |
|---|---|
| `hostPath` | Monta caminho do nó no container |
| `initContainer` | Cria `index.html` antes do NGINX iniciar |
| Persistência por nó | Dados podem permanecer após recriação do Pod no mesmo nó |

## Observação importante (Windows 11)

Mesmo usando Windows 11, o cluster local `k3d-meucluster` executa nó Linux interno (k3s em containers Docker).  
Por isso, `/tmp/k8s-hostpath-demo` é caminho do nó do cluster, não do `C:\` diretamente.

## Arquitetura lógica

```mermaid
flowchart LR
  A[initContainer] --> B[/tmp/k8s-hostpath-demo no nó Linux]
  C[Container nginx] --> B
  B --> D[/usr/share/nginx/html]
```

## Execução no PowerShell

```powershell
cd .\manifests\02-hostpath
kubectl apply -f .
kubectl get pods -n storage-lab
kubectl describe pod -n storage-lab hostpath-demo
```

## Validação do conteúdo

```powershell
kubectl exec -n storage-lab pod/hostpath-demo -- ls -la /usr/share/nginx/html
kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/index.html
kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/history.log
```

Teste HTTP:

```powershell
kubectl port-forward -n storage-lab pod/hostpath-demo 8080:80
curl.exe http://127.0.0.1:8080
```

## Limpeza

```powershell
kubectl delete -f .
```

## Troubleshooting

- `ContainerCreating`: verifique eventos com `kubectl describe pod`.
- Sem arquivo no NGINX: cheque logs do initContainer (`-c init-html`).
- `curl.exe` sem resposta: valide `port-forward` ativo e Pod em `Running`.
- Dúvida sobre caminho: consulte `hostpath-local-test.md`.

## Evidências recomendadas

- `kubectl describe pod -n storage-lab hostpath-demo`
- saída de `cat /usr/share/nginx/html/index.html`
- retorno HTTP via `curl.exe http://127.0.0.1:8080`
