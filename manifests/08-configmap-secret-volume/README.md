# Laboratório 08 - ConfigMap e Secret como volume

## Objetivo

Demonstrar como montar dados de configuração e segredos como arquivos dentro de containers.

## Arquivos

- `namespace.yaml`
- `configmap-app.yaml`
- `pod-configmap-volume.yaml`
- `secret-app.yaml`
- `pod-secret-volume.yaml`

Namespace: `storage-lab-config`.

## Conceitos-chave

| Conceito | Aplicação neste laboratório |
|---|---|
| `ConfigMap` | Dados não sensíveis (`app.properties`, `config.json`) |
| `Secret` | Dados sensíveis (`username`, `password`) |
| Montagem em volume | Cada chave vira arquivo no container |

## Diferença: variável de ambiente vs volume

- Variável de ambiente: simples para chaves pequenas.
- Volume: ideal para apps que leem arquivos de configuração/credenciais.

## Arquitetura lógica

```mermaid
flowchart LR
  A[ConfigMap app-config] --> C[Pod pod-configmap-volume-demo]
  B[Secret app-secret] --> D[Pod pod-secret-volume-demo]
  C --> E[/etc/config/*]
  D --> F[/etc/secret/*]
```

## Execução no PowerShell

```powershell
cd .\manifests\08-configmap-secret-volume
kubectl apply -f namespace.yaml
kubectl apply -f configmap-app.yaml
kubectl apply -f pod-configmap-volume.yaml
kubectl apply -f secret-app.yaml
kubectl apply -f pod-secret-volume.yaml
```

## Validação do ConfigMap em volume

```powershell
kubectl exec -n storage-lab-config pod-configmap-volume-demo -- ls -l /etc/config
kubectl exec -n storage-lab-config pod-configmap-volume-demo -- cat /etc/config/app.properties
kubectl exec -n storage-lab-config pod-configmap-volume-demo -- cat /etc/config/config.json
kubectl describe configmap app-config -n storage-lab-config
```

## Validação do Secret em volume

```powershell
kubectl exec -n storage-lab-config pod-secret-volume-demo -- ls -l /etc/secret
kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/username
kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/password
```

## Segurança e boas práticas

- este exemplo é didático e usa credenciais simples;
- em projetos reais, não versionar segredos reais no GitHub;
- preferir integração com secret manager e pipelines seguros.

## Limpeza

```powershell
kubectl delete -f pod-secret-volume.yaml --ignore-not-found
kubectl delete -f secret-app.yaml --ignore-not-found
kubectl delete -f pod-configmap-volume.yaml --ignore-not-found
kubectl delete -f configmap-app.yaml --ignore-not-found
kubectl delete -f namespace.yaml --ignore-not-found
```

## Troubleshooting

- Pod não sobe por objeto ausente: aplique ConfigMap/Secret antes dos Pods.
- Arquivo não encontrado: confira nomes das chaves em `configmap-app.yaml` e `secret-app.yaml`.
- Segredo “não legível” em YAML: campos em `data` aparecem em base64 por padrão.

## Evidências recomendadas

- `kubectl get configmap,secret,pods -n storage-lab-config`
- leitura dos arquivos em `/etc/config`
- leitura dos arquivos em `/etc/secret`
