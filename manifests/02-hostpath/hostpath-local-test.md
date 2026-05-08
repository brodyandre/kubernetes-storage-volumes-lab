# Teste Local do `hostPath` (Windows 11)

## Contexto técnico

No cluster `k3d-meucluster`, o nó Kubernetes (k3s) roda em ambiente Linux interno em containers Docker.  
Assim, `hostPath: /tmp/k8s-hostpath-demo` aponta para o filesystem do nó do cluster, não para um diretório nativo do Windows.

## 1) Aplicar o laboratório

```powershell
kubectl apply -f .\manifests\02-hostpath
kubectl get pods -n storage-lab
```

## 2) Confirmar arquivos montados

```powershell
kubectl exec -n storage-lab pod/hostpath-demo -- ls -la /usr/share/nginx/html
kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/index.html
kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/history.log
```

## 3) Testar via HTTP

Terminal 1:

```powershell
kubectl port-forward -n storage-lab pod/hostpath-demo 8080:80
```

Terminal 2:

```powershell
curl.exe http://127.0.0.1:8080
```

## 4) Recriar Pod e validar persistência

```powershell
kubectl delete pod -n storage-lab hostpath-demo
kubectl apply -f .\manifests\02-hostpath\pod-hostpath.yaml
kubectl exec -n storage-lab pod/hostpath-demo -- cat /usr/share/nginx/html/history.log
```

Se o histórico anterior permanecer, a persistência no `hostPath` foi confirmada no nó local.

## 5) Diagnóstico rápido

```powershell
kubectl describe pod -n storage-lab hostpath-demo
kubectl logs -n storage-lab pod/hostpath-demo -c init-html
kubectl logs -n storage-lab pod/hostpath-demo -c nginx
```
