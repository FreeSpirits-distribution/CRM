# Passer à Claude Code pour le CRM FSD — Procédure complète

Cible : MBO, sous Windows + OneDrive, repo GitHub `FreeSpirits-distribution/CRM`.

---

## 1. Pré-requis (à installer une seule fois)

| Outil | Lien | Test |
|---|---|---|
| Node.js 18+ | https://nodejs.org | `node --version` |
| Git | https://git-scm.com | `git --version` |
| Windows Terminal + PowerShell 7 | Microsoft Store | `pwsh --version` |
| (optionnel) WSL2 Ubuntu | `wsl --install` | `wsl --status` |

---

## 2. Installer Claude Code

Dans PowerShell :

```powershell
npm install -g @anthropic-ai/claude-code
claude --version
```

Première session :

```powershell
claude
```

→ Authentification par navigateur, même compte Anthropic.

---

## 3. Cloner le repo HORS OneDrive

⚠️ **Important :** ne pas cloner dans `OneDrive\` — la synchro provoque des
conflits pendant que Claude édite des fichiers.

```powershell
mkdir C:\Dev
cd C:\Dev
git clone https://github.com/FreeSpirits-distribution/CRM.git
cd CRM
```

---

## 4. Déposer le kit de démarrage

Copier les 3 fichiers du kit à la racine du repo :

- `CLAUDE.md`
- `.gitignore`
- `README.md`

Puis :

```powershell
git add CLAUDE.md .gitignore README.md
git commit -m "chore: setup Claude Code (CLAUDE.md, .gitignore, README)"
git push
```

---

## 5. Première session Claude Code dans le repo

```powershell
cd C:\Dev\CRM
claude
```

Tape la première instruction :

> Lis `CLAUDE.md` puis fais un audit du repo : structure, taille des fichiers,
> dépendances implicites (Supabase, fonts), endroits où la clé anon est codée
> en dur. Donne-moi un rapport en moins de 200 mots.

Claude va lire le contexte, scanner `index.html` et `proforma.html`, et te
remonter une analyse ciblée.

---

## 6. Connecter Supabase via MCP (recommandé)

Voir le guide dédié : `MCP_SUPABASE_SETUP.md` (fourni dans le kit).

Résumé en 3 étapes :
1. Générer un Personal Access Token : https://supabase.com/dashboard/account/tokens
2. Stocker en variable d'env :
   ```powershell
   [Environment]::SetEnvironmentVariable("SUPABASE_ACCESS_TOKEN", "sbp_...", "User")
   ```
3. Déposer `.mcp.json` à la racine du repo (template fourni dans `MCP_SUPABASE_SETUP.md`),
   project ref déjà préconfiguré : `ajukuwrznhfsfdeejdkl`

---

## 7. Workflow type pour les prochaines tâches

| Phase | Commande / instruction | Objectif |
|---|---|---|
| Ouverture | `cd C:\Dev\CRM ; claude` | Session dans le repo |
| Plan | "Propose un plan pour [tâche]" | Claude écrit un plan, tu valides |
| Exécution | "Vas-y" | Claude édite les fichiers |
| Revue | `git diff` (Claude le fait) | Vérifier les changements |
| Commit | "Commit avec un message clair" | Message conventionnel |
| Push | "Push sur main" | Déploiement Pages auto |

---

## 8. Slash-commands utiles

- `/init` — génère un CLAUDE.md à partir du repo (déjà fait avec ce kit)
- `/clear` — vide le contexte (entre deux gros sujets)
- `/cost` — coût session
- `/review` — review de PR
- `/help` — aide
- `/plugin` — installer des plugins (skills)

---

## 9. Tâches prioritaires à attaquer (ordre suggéré)

1. **Versionner le SQL Supabase**
   *Demander :* "Crée un dossier `db/` et place mon `supabase_schema_v2.sql` dedans, ajoute un `db/README.md` qui explique comment exécuter la migration."

2. **Audit RLS**
   *Demander :* "Lis `db/schema_v2.sql` et liste toutes les policies. Pour chacune, dis-moi si un agent peut voir ou modifier des données qui ne lui appartiennent pas. Format tableau."

3. **Splitter `index.html`**
   *Demander :* "Le fichier `index.html` fait 152 Ko. Propose un plan de split en modules JS (auth, supabase-client, clients, commandes, visites, ui). Pas de bundler — uniquement `<script type='module'>`."

4. **Ajouter une 404**
   *Demander :* "Crée `404.html` qui redirige vers `index.html` avec un message clair. Compatible GitHub Pages."

5. **Tests manuels documentés**
   *Demander :* "Génère `docs/test-plan.md` avec les scénarios de test pour les 3 rôles (admin, manager, agent)."

---

## 10. Hygiène et sécurité

| Règle | Mise en œuvre |
|---|---|
| Jamais la `service_role` dans le repo | `.gitignore` + variable d'env |
| RLS toujours activée en prod | Vérification dans `db/README.md` |
| Tests avec compte agent avant push | Documenté dans `docs/test-plan.md` |
| Pas de données clients réelles dans Git | `.gitignore` exclut `*_export.csv` |
| Branches feature pour gros refactors | `git checkout -b feat/split-index` |

---

## 11. Alias PowerShell (gain de temps)

Édite ton profil :

```powershell
notepad $PROFILE
```

Ajoute :

```powershell
function crm {
    Set-Location C:\Dev\CRM
    claude
}
```

Sauvegarde, recharge :

```powershell
. $PROFILE
```

Tu tapes `crm` → tu es en session.

---

## 12. Checklist finale avant ta première vraie session

- [ ] Node 18+ + Git installés
- [ ] Claude Code installé (`claude --version`)
- [ ] Authentifié (`claude` une fois)
- [ ] Repo cloné dans `C:\Dev\CRM` (hors OneDrive)
- [ ] `CLAUDE.md`, `.gitignore`, `README.md` ajoutés à la racine
- [ ] Commit + push initial fait
- [ ] Variable d'env `SUPABASE_SERVICE_KEY` configurée
- [ ] Alias `crm` dans le profil PowerShell

---

Une fois tout coché : tu lances `crm` et tu commences à itérer.
