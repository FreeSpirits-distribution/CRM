-- =====================================================
-- AUDIT RLS — CRM FSD
-- Projet Supabase : ajukuwrznhfsfdeejdkl
-- =====================================================
-- À coller dans : https://supabase.com/dashboard/project/ajukuwrznhfsfdeejdkl/sql/new
-- 100% lecture seule. Aucune modification de la base.
-- Exécuter chaque bloc séparément (ils renvoient des résultats distincts).
-- =====================================================


-- =====================================================
-- BLOC 1 — Inventaire des tables publiques + état RLS
-- =====================================================
-- Toutes les tables du schéma public, avec leur statut RLS.
-- En production, AUCUNE table ne devrait avoir rowsecurity = false.

SELECT
  schemaname                    AS schema,
  tablename                     AS table_name,
  rowsecurity                   AS rls_active,
  CASE
    WHEN rowsecurity THEN 'OK'
    ELSE 'DANGER : RLS désactivée'
  END                           AS verdict,
  pg_size_pretty(
    pg_total_relation_size(
      format('%I.%I', schemaname, tablename)::regclass
    )
  )                             AS taille
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY rowsecurity ASC, tablename;


-- =====================================================
-- BLOC 2 — Tables avec RLS active mais SANS policy
-- =====================================================
-- Si une table a RLS active mais zéro policy, plus PERSONNE ne peut lire
-- (sauf service_role qui bypasse). C'est souvent un oubli.

SELECT
  t.schemaname,
  t.tablename,
  t.rowsecurity,
  COALESCE(p.nb_policies, 0) AS nb_policies,
  CASE
    WHEN t.rowsecurity AND COALESCE(p.nb_policies, 0) = 0
      THEN 'ATTENTION : RLS active sans aucune policy → tout est bloqué'
    WHEN NOT t.rowsecurity
      THEN 'RLS désactivée'
    ELSE 'OK'
  END AS verdict
FROM pg_tables t
LEFT JOIN (
  SELECT schemaname, tablename, COUNT(*) AS nb_policies
  FROM pg_policies
  GROUP BY schemaname, tablename
) p USING (schemaname, tablename)
WHERE t.schemaname = 'public'
ORDER BY verdict, tablename;


-- =====================================================
-- BLOC 3 — Détail de toutes les policies actives
-- =====================================================
-- Liste exhaustive avec le prédicat USING (lecture) et WITH CHECK (écriture).
-- Lire chaque ligne pour s'assurer que le filtre code_agent est bien appliqué
-- aux rôles 'agent'.

SELECT
  schemaname,
  tablename,
  policyname,
  cmd                           AS commande,    -- SELECT / INSERT / UPDATE / DELETE / ALL
  roles,                                        -- rôle(s) concerné(s)
  permissive,
  qual                          AS using_clause,    -- filtre lecture
  with_check                    AS with_check_clause -- filtre écriture
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, cmd, policyname;


-- =====================================================
-- BLOC 4 — Tables critiques : présence de policies par commande
-- =====================================================
-- Pour chaque table sensible, vérifier qu'on a bien une policy SELECT
-- ET les policies d'écriture nécessaires. Adapte la liste selon ton schéma.

WITH tables_critiques AS (
  SELECT unnest(ARRAY[
    'profiles',
    'clients',
    'commandes',
    'visites',
    'produits'
    -- AJOUTE ICI les tables de ton schéma réel
  ]) AS tablename
),
policies_par_cmd AS (
  SELECT
    tablename,
    cmd,
    COUNT(*) AS nb
  FROM pg_policies
  WHERE schemaname = 'public'
  GROUP BY tablename, cmd
)
SELECT
  t.tablename,
  COALESCE(SUM(CASE WHEN p.cmd IN ('SELECT', 'ALL') THEN p.nb END), 0) AS policies_select,
  COALESCE(SUM(CASE WHEN p.cmd IN ('INSERT', 'ALL') THEN p.nb END), 0) AS policies_insert,
  COALESCE(SUM(CASE WHEN p.cmd IN ('UPDATE', 'ALL') THEN p.nb END), 0) AS policies_update,
  COALESCE(SUM(CASE WHEN p.cmd IN ('DELETE', 'ALL') THEN p.nb END), 0) AS policies_delete
FROM tables_critiques t
LEFT JOIN policies_par_cmd p USING (tablename)
GROUP BY t.tablename
ORDER BY t.tablename;


-- =====================================================
-- BLOC 5 — Présence du filtre code_agent dans les policies
-- =====================================================
-- Repère les policies qui DEVRAIENT mentionner code_agent (filtre par agent)
-- mais qui ne le font pas. À examiner manuellement.

SELECT
  tablename,
  policyname,
  cmd,
  qual           AS using_clause,
  CASE
    WHEN qual ILIKE '%code_agent%' THEN 'OK : filtre code_agent présent'
    WHEN qual ILIKE '%role%' AND (qual ILIKE '%admin%' OR qual ILIKE '%manager%') THEN 'OK : bypass admin/manager'
    WHEN qual IS NULL THEN 'À vérifier : pas de USING (peut être normal pour INSERT)'
    ELSE 'À AUDITER : ni code_agent ni admin/manager dans le filtre'
  END AS verdict
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY verdict, tablename, policyname;


-- =====================================================
-- BLOC 6 — Cohérence profiles ↔ tables métier
-- =====================================================
-- Cherche les codes_agent présents dans les tables métier mais absents
-- de la table profiles. Ce sont des données orphelines.
-- Adapte les FROM selon les tables de ton schéma.

-- A. Codes agent dans clients qui n'existent pas dans profiles
SELECT 'clients' AS source_table, c.code_agent, COUNT(*) AS nb_lignes
FROM public.clients c
LEFT JOIN public.profiles p ON p.code_agent = c.code_agent
WHERE c.code_agent IS NOT NULL AND p.code_agent IS NULL
GROUP BY c.code_agent;

-- B. Idem pour commandes (décommente si la table existe)
-- SELECT 'commandes' AS source_table, c.code_agent, COUNT(*)
-- FROM public.commandes c
-- LEFT JOIN public.profiles p ON p.code_agent = c.code_agent
-- WHERE c.code_agent IS NOT NULL AND p.code_agent IS NULL
-- GROUP BY c.code_agent;


-- =====================================================
-- BLOC 7 — Index sur les colonnes utilisées par les policies
-- =====================================================
-- Une policy qui filtre sur code_agent devient lente sans index.
-- Ce bloc liste les index existants sur les tables critiques.

SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('clients', 'commandes', 'visites', 'profiles')
ORDER BY tablename, indexname;

-- À exécuter ensuite si tu vois qu'un index manque :
-- CREATE INDEX IF NOT EXISTS idx_clients_code_agent ON public.clients (code_agent);
-- CREATE INDEX IF NOT EXISTS idx_commandes_code_agent ON public.commandes (code_agent);


-- =====================================================
-- BLOC 8 — Fonctions SECURITY DEFINER (vecteur de risque)
-- =====================================================
-- Une fonction SECURITY DEFINER s'exécute avec les droits du créateur,
-- pas de l'appelant. Si elle écrit dans une table sensible sans vérifier
-- l'identité, elle court-circuite la RLS. À auditer.

SELECT
  n.nspname     AS schema,
  p.proname     AS fonction,
  CASE p.prosecdef
    WHEN true  THEN 'SECURITY DEFINER (à auditer)'
    ELSE 'SECURITY INVOKER (OK)'
  END           AS securite,
  pg_get_function_arguments(p.oid) AS args,
  pg_get_function_result(p.oid)    AS retour
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind = 'f'
ORDER BY p.prosecdef DESC, p.proname;


-- =====================================================
-- BLOC 9 — Triggers actifs sur les tables critiques
-- =====================================================
-- Liste les triggers (souvent utilisés pour audit, set updated_at, etc.)

SELECT
  event_object_table              AS table_name,
  trigger_name,
  action_timing,                                  -- BEFORE / AFTER
  string_agg(event_manipulation, ', ') AS evenements
FROM information_schema.triggers
WHERE event_object_schema = 'public'
GROUP BY event_object_table, trigger_name, action_timing
ORDER BY event_object_table, trigger_name;


-- =====================================================
-- BLOC 10 — Vérification finale : score de santé RLS
-- =====================================================
-- Une vue d'ensemble en une ligne.

SELECT
  (SELECT COUNT(*) FROM pg_tables WHERE schemaname='public') AS nb_tables_publiques,
  (SELECT COUNT(*) FROM pg_tables WHERE schemaname='public' AND rowsecurity) AS nb_tables_rls,
  (SELECT COUNT(*) FROM pg_tables WHERE schemaname='public' AND NOT rowsecurity) AS nb_tables_sans_rls,
  (SELECT COUNT(*) FROM pg_policies WHERE schemaname='public') AS nb_policies_total,
  (SELECT COUNT(DISTINCT tablename) FROM pg_policies WHERE schemaname='public') AS nb_tables_avec_policies;
