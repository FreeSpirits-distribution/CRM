# Base de données — CRM FSD

Schéma et migrations PostgreSQL pour le projet Supabase
`ajukuwrznhfsfdeejdkl`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `schema.sql` | Schéma de référence (à jour avec la prod) |
| `migrations/` | Migrations versionnées (ordre chronologique) |
| `policies.sql` | Vue d'ensemble des policies RLS actives |
| `seed.sql` | Données de seed pour environnement de dev (optionnel) |

## Récupérer le schéma actuel depuis Supabase

### Option A — depuis le Dashboard (rapide)
1. https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/database/schemas
2. Choisir le schéma `public` puis `Export`
3. Coller dans `db/schema.sql`

### Option B — via `pg_dump` (recommandé pour la rigueur)
Pré-requis : `psql` + variables d'env du `.env`.

```bash
pg_dump \
  --host=db.ajukuwrznhfsfdeejdkl.supabase.co \
  --port=5432 \
  --username=postgres \
  --schema=public \
  --schema-only \
  --no-owner \
  --no-privileges \
  --file=db/schema.sql \
  postgres
```

### Option C — via Supabase CLI (le plus propre, à terme)
```bash
npm install -g supabase
supabase login
supabase link --project-ref ajukuwrznhfsfdeejdkl
supabase db pull
```
→ génère un dossier `supabase/migrations/` proprement.

## Appliquer une migration

1. Ouvrir https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/sql/new
2. Coller le contenu du fichier `.sql`
3. Exécuter
4. Vérifier les policies : `SELECT * FROM pg_policies WHERE schemaname = 'public';`
5. Tester avec un compte `agent` avant de communiquer la mise en prod

## Vérification rapide des RLS

Coller dans l'éditeur SQL Supabase :

```sql
-- Tables avec RLS activée
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Policies actives
SELECT schemaname, tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- Vérifier qu'aucune table publique n'a RLS désactivée
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public' AND rowsecurity = false;
```

La dernière requête doit renvoyer **0 ligne** en production.

## Backup avant migration

Toujours faire un dump avant une migration risquée :

```bash
pg_dump \
  --host=db.ajukuwrznhfsfdeejdkl.supabase.co \
  --port=5432 \
  --username=postgres \
  --no-owner \
  --no-privileges \
  --file=backups/backup_$(date +%Y%m%d_%H%M%S).sql \
  postgres
```

(Le dossier `backups/` est dans le `.gitignore` — ne jamais committer.)
