# CRM FSD — Free Spirits Distribution

CRM interne pour Free Spirits Distribution, distributeur de spiritueux.
Application statique (HTML/JS vanilla, sans build) hébergée sur GitHub Pages,
backend Supabase (PostgreSQL + Auth), cloisonnement par agent via Row Level Security.

**Production :** https://freespirits-distribution.github.io/CRM/

L'écosystème comprend **deux applications** sur le même projet Supabase (`dlpzxngnphxuvopcxenf`) :

| App | Dépôt | Usage |
|---|---|---|
| CRM (cette app) | `FreeSpirits-distribution/CRM` | Outil interne : clients, tournées, relances, CA, proformas, administration |
| Order | `FreeSpirits-distribution/Order` | Portail de commande B2B pour les clients (cavistes / CHR) |

---

## Rôles et permissions

| Rôle | Visibilité lignes | CA | Permissions |
|---|---|---|---|
| `admin` | Tout | Visible | Lecture, écriture, gestion des profils agents, onglet CA, transfert/fusion de codes |
| `manager` | Tout | **Masqué (UI)** | Lecture, écriture — pas de gestion de profils, pas d'onglet CA |
| `agent` | Cloisonné à ses `agent_codes` | Masqué (UI) | Lecture/écriture sur son portefeuille uniquement |

Le cloisonnement des **lignes** est appliqué **côté serveur** (RLS Supabase, voir `db/rls_hardening.sql`).
Le masquage du **CA** (colonne, fiche, exports CSV, totaux tournées) est appliqué **côté UI** via `isAdminRole()` :
la colonne `ca` est tout de même présente dans les réponses API des lignes visibles par l'utilisateur.
Pour un masquage réel côté serveur, appliquer `db/rls_hardening.sql` Partie E (colonne/vue dédiée).

---

## Fonctionnalités principales

- **Clients** : recherche plein texte, filtres Région / Dépt / Agent / Source / statut (chips), scoring, pagination. Les filtres Région, Dépt et Agent sont générés dynamiquement depuis les données. Tri Statut selon l'ordre métier : Top → Actif → Client → Prospect → Inactif → Agent. La sauvegarde d'une fiche ou d'une note conserve la page courante.
- **Fiche client** : panneau latéral lecture/édition, notes, relances, géolocalisation, distances entrepôts, édition rapide (quick edit).
- **Tournées** : planificateur hebdomadaire par secteur/direction, drag & drop, export CSV/PDF, relances à 14 jours.
- **CA** (admin) : KPIs (TTC/HT/HDHT, droits d'accises, TVA, bouteilles, panier moyen, commission), top clients, saisie de commandes, proformas agents.
- **Proforma** (`proforma.html`) : générateur de proforma PDF (jsPDF).
- **Admin** : gestion des profils agents (création via signup + métadonnées, rôles, codes multiples, reset mot de passe par email), suppression d'agent avec transfert ou désassignation de son portefeuille (clients, commandes, relances), outil de transfert/fusion de codes agents.
- **PWA** : installable (manifest + icônes), utilisable sur iPhone/PC.

---

## Stack

- HTML/CSS/JS vanilla — un seul fichier par app, aucun build
- Supabase : PostgreSQL, Auth (email/password), RLS, REST (PostgREST)
- GitHub Pages : déploiement automatique à chaque push sur `main`
- jsPDF + AutoTable (CDN cloudflare, avec SRI) pour les exports PDF

---

## Structure du dépôt

```
.
├── index.html                        # CRM complet (UI + logique + appels Supabase)
├── proforma.html                     # Générateur de proforma
├── common.js                         # Constantes partagées (URL + clé anon Supabase)
├── logo.js / logo.png / icon-*.png   # Assets
├── manifest.webmanifest              # PWA
├── .github/workflows/keepalive.yml   # Ping REST quotidien (anti-pause plan gratuit)
├── db/                               # SQL versionné
│   ├── rls_hardening.sql             # Policies RLS + durcissements (référence)
│   ├── audit_rls.sql                 # Script d'audit des policies en place
│   ├── perf_indexes.sql              # Index de performance
│   ├── migration_admin_2026-06-25.sql
│   ├── migration_producteur_2026-06-25.sql
│   ├── verif_base_clients.sql / corrections_cp_verifiees.sql
│   └── TUTO_AUDIT.md / README.md
├── CLAUDE.md                         # Mémoire projet pour Claude Code
└── README.md
```

⚠️ `db/README.md` référence encore le projet Supabase `ajukuwrznhfsfdeejdkl` (environnement de test) ;
la production est `dlpzxngnphxuvopcxenf` (celle de `common.js`). Toujours vérifier la cible avant d'exécuter un SQL.

---

## Démarrage local

```bash
git clone https://github.com/FreeSpirits-distribution/CRM.git
cd CRM
npx serve .   # ou ouvrir index.html directement
```

La clé utilisée par le front est la clé **anon** (publique par design), définie dans `common.js`.
Ne jamais y placer la clé `service_role`.

---

## Déploiement

Push sur `main` → GitHub Pages publie en ~1 minute. Penser à Ctrl+F5 (et à rouvrir la PWA) après publication.

Migrations SQL : exécuter les fichiers de `db/` dans l'éditeur SQL Supabase du projet **prod**,
puis vérifier les policies avec `db/audit_rls.sql` et tester avec un compte `agent`.

---

## Emails (Supabase Auth)

Les emails transactionnels (confirmation d'inscription, invitation, reset mot de passe) partent via le SMTP
configuré dans Supabase → Authentication → SMTP.

- **SMTP par défaut Supabase** : limité à ~2 emails/heure et aux adresses membres de l'équipe Supabase — suffisant pour les resets internes, pas pour les inscriptions clients.
- **SMTP custom (Brevo ou OVH)** : requis pour que les inscriptions du portail Order fonctionnent en réel. Domaine `free-spirits.fr` à authentifier (SPF/DKIM) chez le fournisseur choisi.

En l'absence de SMTP custom, un compte client peut être confirmé manuellement :
Dashboard → Authentication → Users → ⋯ → Confirm email.

---

## Sécurité

- La clé `service_role` ne doit jamais apparaître dans le code, le dépôt (public) ou les workflows.
- Le signup Supabase est **ouvert** (nécessaire au portail Order) : le trigger `handle_new_user` ne doit **jamais** accepter un rôle privilégié (`admin`/`manager`) venant des métadonnées d'inscription — promotion uniquement via le panneau admin. Vérifier avec `db/audit_rls.sql`.
- Sessions : token stocké en `localStorage` — toute injection XSS serait critique ; conserver l'échappement systématique (`esc()`) sur tout rendu de données.
- Produits lisibles par `anon` (nécessaire au portail Order avant login) : ne stocker aucune donnée sensible dans `produits`.
- Audit et durcissement : `db/TUTO_AUDIT.md` + `db/rls_hardening.sql`.
