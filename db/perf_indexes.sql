-- =====================================================
-- INDEX DE PERFORMANCE — CRM FSD
-- =====================================================
-- À appliquer sur le projet de PRODUCTION : dlpzxngnphxuvopcxenf
-- (Dashboard Supabase → SQL editor). 100 % additif, sans risque.
--
-- Accélère :
--   - le tri des contacts par score (chargement initial),
--   - le filtrage RLS et les transferts par code agent,
--   - le tri / regroupement du chiffre d'affaires (commandes).
-- Sans index, ces opérations font un balayage complet de la table
-- à chaque requête, ce qui ralentit fortement dès quelques milliers de lignes.
-- =====================================================

-- Contacts : tri par score (order=score.desc au chargement)
create index if not exists idx_contacts_score on public.contacts (score desc);

-- Contacts : cloisonnement RLS + transfert/suppression par agent
create index if not exists idx_contacts_agent on public.contacts (agent);

-- Commandes : tri par date (ecran CA) + transfert par code agent
create index if not exists idx_commandes_date        on public.commandes (date desc);
create index if not exists idx_commandes_agent_code  on public.commandes (agent_code);

-- Relances : cloisonnement RLS + transfert par code agent
create index if not exists idx_relances_code_agent   on public.relances (code_agent);

-- Verification : lister les index crees
-- select tablename, indexname from pg_indexes
-- where schemaname='public' and indexname like 'idx_%' order by tablename;
