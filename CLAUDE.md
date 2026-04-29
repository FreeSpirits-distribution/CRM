# CRM FSD — Free Spirits Distribution

## Contexte métier
CRM interne de Free Spirits Distribution (distributeur de spiritueux).
Utilisateurs : agents commerciaux terrain (tournées, prospection, relances).
Admin : MBO (Maximilien Bonne — auteur du repo).
Manager : LCB (plusieurs comptes possibles, visibilité totale, sans gestion de profils).

## Stack
- Frontend : HTML/CSS/JS vanilla, monolithique pour l'instant
- Hébergement : GitHub Pages (branch `main`, déploiement automatique)
- Backend : Supabase (PostgreSQL + Auth + Row Level Security)
- Pas de framework JS (volontaire — simplicité, pas de build, pas de dépendances)
- Pas de bundler, pas de Node côté front

## Coordonnées Supabase
- Project ref : `ajukuwrznhfsfdeejdkl`
- URL API : `https://ajukuwrznhfsfdeejdkl.supabase.co`
- Dashboard : https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl
- Editeur SQL : https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/sql/new
- Auth users : https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/auth/users
- Table editor : https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/editor
- API settings : https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/settings/api

## Architecture multi-agents (V2)
- Table `profiles` : mapping `auth.uid()` → `code_agent` + `role` (`admin` / `manager` / `agent`)
- RLS activée sur toutes les tables sensibles
- Agent : voit uniquement les lignes où `code_agent = (SELECT code_agent FROM profiles WHERE id = auth.uid())`
- Manager + admin : SELECT sans restriction
- Le CA n'est PAS visible côté agent (filtre RLS + masquage UI dans `index.html`)
- Seul `admin` accède au panneau de gestion des profils

## Fichiers du repo
- `index.html` (~152 Ko) — CRM principal, monolithique. À splitter à terme.
- `proforma.html` (~40 Ko) — Générateur de proforma client.
- `supabase_schema_v2.sql` — *à versionner dans le repo* (actuellement seulement en local)
- `GUIDE_DEPLOIEMENT_CRM_V2.pdf` — *à versionner aussi, ou à mettre dans `/docs`*

## Conventions
- Langue : français pour commentaires, UI et docs
- Unités : grammes, litres, mètres, moles (cf. préférences MBO)
- Indentation : 2 espaces (HTML/JS/CSS)
- Strings : guillemets simples en JS, doubles en HTML
- Pas de framework lourd sans validation explicite (objectif : maintenance simple par MBO seul)

## Sécurité — non négociable
- Côté front, UNIQUEMENT la `anon key` Supabase
- La `service_role key` ne doit JAMAIS apparaître dans le code source ni dans Git
- RLS toujours activée en production sur `clients`, `commandes`, `visites`, `profiles`
- Les filtres côté UI ne remplacent jamais une policy RLS (défense en profondeur)
- Avant tout commit touchant la sécurité : relire les policies et tester avec un compte agent

## Commandes utiles
- Test local rapide : ouvrir `index.html` directement (file://) ou `npx serve .`
- Déploiement : `git push origin main` → GitHub Pages publie dans la minute
- Migration Supabase : copier le contenu de `supabase_schema_v2.sql` dans l'éditeur SQL Supabase, exécuter dans l'ordre
- URL prod : https://freespirits-distribution.github.io/CRM/

## Tâches prioritaires (avril 2026)
1. Créer `.gitignore` propre (ne jamais committer `.env`, clés, dumps)
2. Versionner `supabase_schema_v2.sql` dans le repo (`/db/`)
3. Audit des policies RLS — vérifier qu'aucun trou ne laisse fuiter le CA
4. Splitter `index.html` (152 Ko) en modules JS logiques (auth, clients, commandes, UI)
5. Ajouter une page `404.html` pour GitHub Pages
6. Documenter le déploiement dans `README.md`

## À éviter
- Ne pas désactiver RLS, même temporairement, en production
- Ne pas introduire React/Vue/Svelte sans validation MBO
- Ne pas committer de PDF ou de dump de base sans purge des données clients réelles
- Ne pas casser la rétrocompatibilité des liens (clients agents commerciaux ont des bookmarks)

## Profil utilisateur
Maximilien (MBO) — commercial spiritueux, code en autodidacte, préfère les solutions
robustes, simples, à faible coût de maintenance. Réponses attendues : structurées,
techniques, avec arbitrages clairs et plans pas à pas.
