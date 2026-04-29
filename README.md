# CRM FSD — Free Spirits Distribution

CRM interne pour Free Spirits Distribution, distributeur de spiritueux.
Architecture statique (HTML/JS vanilla) sur GitHub Pages, backend Supabase avec
cloisonnement par agent via Row Level Security.

**Production :** https://freespirits-distribution.github.io/CRM/

---

## Pour qui

| Rôle | Visibilité | Permissions |
|---|---|---|
| `admin` (MBO) | Tout | Lecture, écriture, gestion des profils |
| `manager` (LCB) | Tout | Lecture, écriture (pas de gestion de profils) |
| `agent` | Cloisonné à son `code_agent` | Lecture/écriture sur ses propres données. CA masqué. |

Le cloisonnement est appliqué **côté serveur** (RLS Supabase) et **côté UI**.

---

## Stack

- HTML/CSS/JS vanilla (pas de build)
- Supabase (PostgreSQL + Auth + RLS)
- GitHub Pages (déploiement automatique sur push `main`)

---

## Structure du repo

```
.
├── index.html              # CRM principal (auth, clients, commandes, visites)
├── proforma.html           # Générateur de proforma client
├── db/
│   └── schema_v2.sql       # Migration SQL : profiles + RLS (à versionner)
├── docs/
│   └── deploiement.md      # Procédure de déploiement
├── CLAUDE.md               # Mémoire projet pour Claude Code
├── .gitignore
└── README.md
```

---

## Démarrage local

Aucun build n'est nécessaire.

```bash
git clone https://github.com/FreeSpirits-distribution/CRM.git
cd CRM
# Ouvrir index.html dans le navigateur
# OU servir avec un serveur statique pour éviter les problèmes CORS
npx serve .
```

Configurer la clé Supabase **anon** dans `index.html` (jamais la `service_role`).

---

## Déploiement

Push sur `main` → GitHub Pages publie automatiquement (~1 min).

Pour une migration SQL :
1. Copier `db/schema_v2.sql` dans l'éditeur SQL Supabase
2. Exécuter
3. Vérifier les policies RLS (`SELECT * FROM pg_policies;`)
4. Tester avec un compte agent (visibilité restreinte attendue)

---

## Sécurité

- ❌ Ne jamais committer la clé `service_role` Supabase
- ❌ Ne jamais désactiver RLS en production
- ✅ Tester chaque modification avec un compte `agent` avant push
- ✅ Auditer régulièrement les policies (`SELECT * FROM pg_policies WHERE schemaname = 'public';`)

---

## Auteur

Maximilien Bonne (MBO) — Free Spirits Distribution
