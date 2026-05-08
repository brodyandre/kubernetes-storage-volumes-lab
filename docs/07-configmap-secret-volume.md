# 07 - ConfigMap e Secret montados como volume

## 1. Explicação conceitual

`ConfigMap` e `Secret` são objetos para injetar configuração em Pods:

- `ConfigMap`: dados não sensíveis;
- `Secret`: dados sensíveis.

### Tabela comparativa

| Recurso | Finalidade | Exemplo neste projeto |
|---|---|---|
| `ConfigMap` | Configuração não sensível | `app.properties`, `config.json` |
| `Secret` | Credenciais/segredos | `username`, `password` |

Além de variáveis de ambiente, ambos podem ser montados como volume.  
Quando montados como volume, cada chave vira um arquivo dentro do container.

Comparação rápida:

- variável de ambiente: leitura simples por processo, mas menos prática para arquivos estruturados;
- volume: ideal para apps que esperam arquivo de configuração (ex.: `.properties`, `.json`, certificados, chaves).

## 2. Quando usar

- aplicação lê configuração por arquivo;
- segredo precisa ser entregue como arquivo (ex.: token/certificado);
- você quer separar configuração da imagem do container.

## 3. Quando evitar

- segredos reais versionados em repositório Git;
- arquivos muito grandes ou binários pesados (ConfigMap/Secret não são storage de dados de negócio);
- quando só uma variável simples já resolve e não há necessidade de arquivos.

## 4. Exemplo prático

Lab `manifests/08-configmap-secret-volume`:

- `configmap-app.yaml` cria `app-config` com `app.properties` e `config.json`;
- `pod-configmap-volume.yaml` monta em `/etc/config`;
- `secret-app.yaml` cria `app-secret` (`username`, `password`) tipo `Opaque`;
- `pod-secret-volume.yaml` monta em `/etc/secret`.
- cenário executado no cluster local `k3d-meucluster`.

Observação didática importante:

- este exemplo usa credenciais simples para facilitar estudo;
- em projetos reais, nunca publique senha real no GitHub.

## 5. Diagrama Mermaid

```mermaid
flowchart LR
  A[ConfigMap app-config] --> C[Pod pod-configmap-volume-demo]
  B[Secret app-secret] --> D[Pod pod-secret-volume-demo]
  C --> E[/etc/config/app.properties]
  C --> F[/etc/config/config.json]
  D --> G[/etc/secret/username]
  D --> H[/etc/secret/password]
```

## 6. Comandos kubectl úteis (PowerShell)

```powershell
# Aplicar namespace e objetos
kubectl apply -f .\manifests\08-configmap-secret-volume\namespace.yaml
kubectl apply -f .\manifests\08-configmap-secret-volume\configmap-app.yaml
kubectl apply -f .\manifests\08-configmap-secret-volume\pod-configmap-volume.yaml
kubectl apply -f .\manifests\08-configmap-secret-volume\secret-app.yaml
kubectl apply -f .\manifests\08-configmap-secret-volume\pod-secret-volume.yaml

# Verificar objetos
kubectl get configmap,secret,pods -n storage-lab-config
kubectl describe configmap app-config -n storage-lab-config
kubectl describe secret app-secret -n storage-lab-config

# Ler arquivos do ConfigMap montado
kubectl exec -n storage-lab-config pod-configmap-volume-demo -- ls -l /etc/config
kubectl exec -n storage-lab-config pod-configmap-volume-demo -- cat /etc/config/app.properties
kubectl exec -n storage-lab-config pod-configmap-volume-demo -- cat /etc/config/config.json

# Ler arquivos do Secret montado
kubectl exec -n storage-lab-config pod-secret-volume-demo -- ls -l /etc/secret
kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/username
kubectl exec -n storage-lab-config pod-secret-volume-demo -- cat /etc/secret/password
```

## 7. Erros comuns e como resolver

- **Pod não inicia por objeto inexistente**  
  Se ConfigMap/Secret não existir antes do Pod, haverá erro de mount. Aplique-os primeiro.

- **Arquivo esperado não aparece**  
  Confirme se a chave existe em `data` (ConfigMap) ou `stringData`/`data` (Secret).

- **Confusão ao inspecionar Secret com `kubectl get -o yaml`**  
  Valores em `data` aparecem em Base64. Para laboratório, `stringData` simplifica criação.

- **Risco de exposição de segredo**  
  Evite commitar segredos reais. Para produção, use ferramentas de gestão de segredos e pipeline seguro.

- **Interpretação de caminho local no Windows**  
  Os arquivos montados existem dentro do container. Use `kubectl exec` para leitura.

## 8. Resumo final

Montar ConfigMap e Secret como volume é uma estratégia prática para separar configuração da imagem, melhorar organização e simplificar apps que leem arquivos. A diferença crítica é tratar Secret com segurança desde o desenvolvimento.
