# Brancher Supabase à Claude Code (MCP)

Cible : projet Supabase `ajukuwrznhfsfdeejdkl`.

Une fois branché, tu peux dans Claude Code dire :

> "Liste les tables du schéma public et leurs policies RLS"
> "Compte les clients par code_agent"
> "Vérifie qu'aucune table publique n'a RLS désactivée"

Et Claude interroge ta base directement.

---

## 1. Récupérer ton Personal Access Token Supabase

⚠️ Pour le MCP officiel Supabase, on utilise un **Personal Access Token** (PAT)
de ton compte, **pas la `service_role`**.

1. Aller sur https://supabase.com/dashboard/account/tokens
2. Cliquer "Generate new token"
3. Nom suggéré : `claude-code-crm-fsd`
4. Copier le token (commence par `sbp_...`) — affiché une seule fois

---

## 2. Stocker le token en variable d'env Windows

PowerShell, en utilisateur courant (sans admin) :

```powershell
[Environment]::SetEnvironmentVariable("SUPABASE_ACCESS_TOKEN", "sbp_TON_TOKEN_ICI", "User")
```

Fermer puis rouvrir le terminal pour que la variable soit chargée.

Vérifier :
```powershell
echo $env:SUPABASE_ACCESS_TOKEN
```

---

## 3. Ajouter le MCP à Claude Code

Dans le repo (`C:\Dev\CRM`), créer ou éditer `.mcp.json` :

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": [
        "-y",
        "@supabase/mcp-server-supabase@latest",
        "--read-only",
        "--project-ref=ajukuwrznhfsfdeejdkl"
      ],
      "env": {
        "SUPABASE_ACCESS_TOKEN": "${SUPABASE_ACCESS_TOKEN}"
      }
    }
  }
}
```

Le flag `--read-only` est **fortement recommandé** au début — Claude pourra lire
le schéma et les données mais pas modifier la base. À retirer plus tard quand tu
es à l'aise (et avec des sauvegardes en place).

`.mcp.json` est partageable côté repo (pas de secret dedans, le token vient de
l'env).

---

## 4. Lancer Claude Code et autoriser le MCP

```powershell
cd C:\Dev\CRM
claude
```

Au premier lancement, il détecte `.mcp.json` et te demande l'autorisation.
Confirme.

Vérifier que le MCP est connecté :
```
/mcp
```
→ doit afficher `supabase` avec ses outils disponibles.

---

## 5. Tester avec une question simple

Dans la session Claude Code :

> "Via le MCP supabase, donne-moi la liste des tables du schéma public avec
> leur nombre de lignes et l'état de RLS. Format tableau Markdown."

Claude doit te répondre avec un vrai tableau extrait de ta base.

---

## 6. Commandes utiles à demander à Claude une fois branché

| Question | Ce que ça produit |
|---|---|
| "Liste les policies RLS sur la table `clients` et dis-moi si un agent peut voir les clients d'un autre agent" | Audit sécurité |
| "Combien de clients par `code_agent` ?" | Stats rapides |
| "Y a-t-il des `code_agent` dans `clients` qui n'existent pas dans `profiles` ?" | Détection d'incohérences |
| "Génère un script SQL d'idempotence pour ajouter une colonne `derniere_visite TIMESTAMPTZ` à `clients` si elle n'existe pas, avec backfill depuis `visites`" | Migration prête à l'emploi |
| "Liste les triggers et fonctions stockées" | Inventaire complet |

---

## 7. Sécurité

- ✅ Token PAT stocké en variable d'env Windows, jamais en dur
- ✅ `.mcp.json` peut être committé (pas de secret dedans)
- ✅ Mode `--read-only` au démarrage
- ❌ Ne jamais mettre la `service_role` dans le MCP (le PAT suffit)
- ❌ Ne pas révoquer le PAT avant d'avoir prévenu : tous les outils branchés cassent

---

## 8. En cas de souci

| Symptôme | Cause probable | Solution |
|---|---|---|
| `/mcp` ne montre pas `supabase` | `.mcp.json` mal placé | Le mettre à la racine du repo |
| Erreur d'auth | Token expiré ou faux | Régénérer un PAT |
| Claude refuse une action d'écriture | Mode `--read-only` actif | Retirer le flag (avec prudence) |
| `npx` lent au démarrage | Pré-télécharger : `npx -y @supabase/mcp-server-supabase@latest --help` |
| Le MCP timeout | Limite Supabase free tier | Restreindre les requêtes ou upgrade |

---

## Alternative sans MCP : `psql` + variables d'env

Si tu préfères ne pas utiliser MCP, Claude Code peut quand même piloter la base
en exécutant `psql` via Bash, à condition que `psql` soit installé et que ton
`.env` soit chargé. Plus rustique, mais ça marche.
