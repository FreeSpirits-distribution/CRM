# Tuto — Faire un audit RLS en 5 minutes

Pas besoin d'installer quoi que ce soit. Juste copier-coller dans ton dashboard.

---

## Étape 1 — Ouvrir l'éditeur SQL Supabase

https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/sql/new

---

## Étape 2 — Coller `audit_rls.sql` bloc par bloc

Le fichier est découpé en **10 blocs indépendants**. Ne pas tout exécuter d'un
coup — chaque bloc renvoie un résultat distinct, plus lisible séparément.

| Bloc | Ce que ça te dit | Verdict attendu |
|---|---|---|
| 1 | Tables avec / sans RLS | Toutes les tables sensibles doivent avoir `rls_active = true` |
| 2 | Tables RLS active mais sans policy | 0 ligne avec verdict "ATTENTION" |
| 3 | Liste détaillée des policies | À lire : chaque policy doit avoir un `qual` cohérent |
| 4 | Couverture des commandes (SELECT/INSERT/UPDATE/DELETE) | Pas de zéro sur les tables critiques |
| 5 | Présence du filtre `code_agent` | Verdict "À AUDITER" doit être expliqué |
| 6 | Codes agent orphelins | 0 ligne idéalement |
| 7 | Index sur colonnes RLS | Index sur `code_agent` recommandé |
| 8 | Fonctions SECURITY DEFINER | Auditer chacune individuellement |
| 9 | Triggers | Inventaire (pas de verdict automatique) |
| 10 | Score de santé global | nb_tables_publiques = nb_tables_rls |

---

## Étape 3 — Coller le résultat à Claude Code

Une fois le repo configuré, tu peux dire à Claude Code :

> "Voici la sortie des 10 blocs de l'audit RLS [coller les résultats].
> Identifie les 5 problèmes les plus critiques par ordre de gravité,
> et propose les correctifs SQL pour chacun."

Claude te sortira un plan d'action priorisé.

---

## Étape 4 — Versionner le schéma actuel

Deux options :

### Option A — sans rien installer (Dashboard)
1. https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/database/schemas
2. Schéma `public` → bouton Export ou copier le DDL
3. Coller dans `db/schema.sql`
4. `git add db/schema.sql && git commit && git push`

### Option B — avec `pg_dump` (script fourni)
1. Installer PostgreSQL client (Windows) : https://www.postgresql.org/download/windows/
2. Récupérer le mot de passe DB : Dashboard > Settings > Database
3. Lancer `.\db\dump_schema.ps1` depuis la racine du repo
4. `git diff db/schema.sql` puis commit

### Option C — avec Supabase CLI (le plus propre à long terme)
```powershell
npm install -g supabase
supabase login
supabase link --project-ref ajukuwrznhfsfdeejdkl
supabase db pull
```
Génère un dossier `supabase/migrations/` avec un fichier daté.

---

## Que faire après l'audit ?

L'audit te donne une photo de l'existant. Les actions classiques après :

1. **Activer RLS sur les tables qui l'ont oubliée**
   ```sql
   ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;
   ```

2. **Ajouter un index sur `code_agent`** si manquant
   ```sql
   CREATE INDEX IF NOT EXISTS idx_<table>_code_agent
   ON public.<table> (code_agent);
   ```

3. **Tester avec un compte agent réel** :
   - Auth en tant qu'agent X
   - Tenter `SELECT * FROM clients` → ne doit voir QUE ses clients
   - Tenter `SELECT SUM(montant) FROM commandes` → ne doit voir QUE le sien
   - Tenter `UPDATE clients SET ... WHERE code_agent = 'AUTRE'` → doit échouer

4. **Logger les tentatives d'accès refusées** (optionnel mais utile en prod)

---

## En cas de doute sur une policy

Pattern de policy multi-rôles standard pour ton cas :

```sql
-- SELECT : agent voit le sien, manager/admin voient tout
CREATE POLICY clients_select_policy ON public.clients
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (
        p.role IN ('admin', 'manager')
        OR p.code_agent = clients.code_agent
      )
  )
);

-- INSERT : agent ne peut insérer que pour lui-même, admin/manager pour tous
CREATE POLICY clients_insert_policy ON public.clients
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (
        p.role IN ('admin', 'manager')
        OR p.code_agent = clients.code_agent
      )
  )
);

-- UPDATE : même logique, USING pour qui peut tenter, WITH CHECK pour le résultat
CREATE POLICY clients_update_policy ON public.clients
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p.role IN ('admin', 'manager') OR p.code_agent = clients.code_agent)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p.role IN ('admin', 'manager') OR p.code_agent = clients.code_agent)
  )
);

-- DELETE : souvent réservé admin uniquement
CREATE POLICY clients_delete_policy ON public.clients
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);
```

À adapter selon ton schéma réel.
