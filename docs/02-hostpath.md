# 02 - hostPath no Kubernetes (Windows 11 + cluster local)

## 1. Explicação conceitual

`hostPath` é um tipo de volume que monta um diretório do nó Kubernetes dentro de um container.

Em vez de guardar arquivos somente dentro do filesystem do container (que pode ser descartado), o Pod passa a usar um caminho do nó. Isso permite que o dado sobreviva à recriação do container, desde que continue no mesmo nó.

Observação importante para este projeto:

- mesmo em Windows 11, o cluster `k3d-meucluster` usa um nó Linux interno (k3s em containers Docker);
- portanto, `/tmp/k8s-hostpath-demo` existe no nó Linux do cluster, não no `C:\` do Windows.

### Tabela rápida

| Item | `hostPath` neste projeto |
|---|---|
| Tipo de storage | Diretório do nó Kubernetes |
| Escopo | Dependente de nó |
| Namespace de exemplo | `storage-lab` |
| Caso de uso aqui | Laboratório e aprendizado |

## 2. Quando usar

- laboratórios e estudo do comportamento de volumes;
- cenários locais simples com cluster de nó único;
- debugging em que você precisa inspecionar dados rapidamente no nó.

## 3. Quando evitar

- produção com múltiplos nós;
- aplicações que precisam mover Pods entre nós sem perda de dados;
- ambientes com requisitos fortes de segurança e isolamento.

Motivo: `hostPath` acopla o Pod a um nó específico e expõe parte do filesystem do nó ao container.

## 4. Exemplo prático

No laboratório `manifests/02-hostpath`:

- Pod `hostpath-demo` no namespace `storage-lab`;
- `initContainer` (BusyBox) cria `index.html`;
- NGINX monta o mesmo volume em `/usr/share/nginx/html`;
- o conteúdo servido pelo NGINX vem do `hostPath`.

Trecho didático:

```yaml
volumes:
  - name: host-html
    hostPath:
      path: /tmp/k8s-hostpath-demo
      type: DirectoryOrCreate

volumeMounts:
  - name: host-html
    mountPath: /usr/share/nginx/html
```

## 5. Diagrama Mermaid

```mermaid
flowchart LR
  A[initContainer cria index.html] --> B[Volume hostPath]
  B --> C[/tmp/k8s-hostpath-demo no nó Linux]
  C --> D[Container nginx monta em /usr/share/nginx/html]
  D --> E[Resposta HTTP com o arquivo do volume]
```

## 6. Comandos kubectl úteis (PowerShell)

```powershell
# Aplicar o laboratório
kubectl apply -f .\manifests\02-hostpath

# Inspecionar estado
kubectl get pods -n storage-lab
kubectl describe pod -n storage-lab hostpath-demo

# Verificar se o initContainer criou o arquivo
kubectl logs -n storage-lab pod/hostpath-demo -c init-html

# Ler conteúdo dentro do Pod
kubectl exec -n storage-lab pod/hostpath-demo -- ls -la /usr/share/nginx/html
kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/index.html

# Testar via HTTP
kubectl port-forward -n storage-lab pod/hostpath-demo 8080:80
curl.exe http://127.0.0.1:8080
```

## 7. Erros comuns e como resolver

- **Pod preso em `ContainerCreating`**  
  Rode `kubectl describe pod -n storage-lab hostpath-demo` e verifique a seção `Events`.

- **`index.html` não foi criado**  
  Verifique logs do initContainer com `kubectl logs -n storage-lab pod/hostpath-demo -c init-html`.

- **Retorno 403/404 no NGINX**  
  Confirme se o arquivo existe em `/usr/share/nginx/html` e se o mount está no caminho correto.

- **Confusão com o filesystem do Windows**  
  O caminho `/tmp/k8s-hostpath-demo` não é um diretório nativo do Windows. Ele está no nó Linux interno do cluster local.

## 8. Resumo final

`hostPath` é ótimo para aprendizado de montagem de volume e persistência por nó em ambiente local. Para produção, prefira armazenamento desacoplado do nó (por exemplo, drivers CSI com `PersistentVolume` e `StorageClass`).
