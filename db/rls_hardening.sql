-- =====================================================
-- DURCISSEMENT RLS + FONCTIONS — CRM FSD
-- =====================================================
-- Projet Supabase de PRODUCTION visé : dlpzxngnphxuvopcxenf
--   (celui référencé dans index.html / proforma.html)
-- À coller dans : https://supabase.com/dashboard/project/dlpzxngnphxuvopcxenf/sql/new
--
-- Ce script est IDEMPOTENT (ré-exécutable sans casse).
-- Il versionne l'état réel des policies + corrige les points remontés
-- par le linter Supabase (get_advisors : security) :
--   1. function_search_path_mutable  → search_path figé sur les fonctions
--   2. rls_policy_always_true        → WITH CHECK (true) sur contacts_insert / commandes_insert
--   3. anon_security_definer_*        → EXECUTE retiré au rôle anon
--
-- IMPORTANT : le compte Supabase connecté à l'audit ne voit PAS le projet
-- de prod (dlpzx...). Ce modèle a été reconstruit à partir d'un projet au
-- schéma identique. VÉRIFIER chaque bloc avant application en prod, et
-- exécuter d'abord sur un projet de test.
-- =====================================================


-- =====================================================
-- PARTIE A — Fonctions d'aide (SECURITY DEFINER) avec search_path figé
-- =====================================================
-- Corrige l'alerte "function_search_path_mutable". Comportement inchangé :
-- toutes les références sont désormais qualifiées (public., auth.) et
-- search_path est vidé pour empêcher tout détournement par un schéma pirate.

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_admin_or_manager()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'manager')
  );
$$;

create or replace function public.can_see_all()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'manager')
  );
$$;

create or replace function public.get_user_agent_code()
returns text language sql stable security definer set search_path = ''
as $$
  select agent_code from public.profiles where id = auth.uid();
$$;

create or replace function public.get_user_agent_codes()
returns text[] language sql stable security definer set search_path = ''
as $$
  select coalesce(agent_codes, array[]::text[]) || array[coalesce(agent_code, '')]
  from public.profiles where id = auth.uid();
$$;


-- =====================================================
-- PARTIE B — Droits d'exécution des fonctions
-- =====================================================
-- Corrige "anon_security_definer_function_executable".
-- Le rôle anon (clé publique) ne doit PAS pouvoir appeler ces fonctions via RPC.
-- Le rôle authenticated en a besoin (évaluation des policies RLS).

revoke execute on function
  public.is_admin(),
  public.is_admin_or_manager(),
  public.can_see_all(),
  public.get_user_agent_code(),
  public.get_user_agent_codes()
from public, anon;

grant execute on function
  public.is_admin(),
  public.is_admin_or_manager(),
  public.can_see_all(),
  public.get_user_agent_code(),
  public.get_user_agent_codes()
to authenticated;

-- Fonction trigger : jamais appelée directement, personne n'a besoin d'EXECUTE.
revoke execute on function public.handle_new_user() from public, anon, authenticated;


-- =====================================================
-- PARTIE C — Activation RLS (idempotent)
-- =====================================================
alter table public.contacts       enable row level security;
alter table public.clients_order  enable row level security;
alter table public.produits       enable row level security;
alter table public.profiles       enable row level security;
alter table public.commandes      enable row level security;
alter table public.relances       enable row level security;


-- =====================================================
-- PARTIE D — Policies : baseline versionnée + DURCISSEMENT
-- =====================================================
-- Chaque table : DROP IF EXISTS puis CREATE, pour un état déterministe.
-- Les lignes marquées [DURCI] changent le comportement actuel.

-- ---------- contacts (cloisonnement par agent) ----------
drop policy if exists contacts_select on public.contacts;
create policy contacts_select on public.contacts for select to authenticated
using (
  public.is_admin_or_manager()
  or agent = public.get_user_agent_code()
  or agent = any(public.get_user_agent_codes())
);

-- [DURCI] avant : WITH CHECK (true) → tout compte pouvait créer un contact
-- assigné à n'importe quel agent. Désormais : admin/manager, ou l'agent
-- ne peut créer que des contacts rattachés à SON code.
drop policy if exists contacts_insert on public.contacts;
create policy contacts_insert on public.contacts for insert to authenticated
with check (
  public.is_admin_or_manager()
  or agent = public.get_user_agent_code()
  or agent = any(public.get_user_agent_codes())
);

drop policy if exists contacts_update on public.contacts;
create policy contacts_update on public.contacts for update to authenticated
using (
  public.is_admin_or_manager()
  or agent = public.get_user_agent_code()
  or agent = any(public.get_user_agent_codes())
)
with check (
  public.is_admin_or_manager()
  or agent = public.get_user_agent_code()
  or agent = any(public.get_user_agent_codes())
);

drop policy if exists contacts_delete on public.contacts;
create policy contacts_delete on public.contacts for delete to authenticated
using (public.is_admin());

-- ---------- commandes (cloisonnement par agent) ----------
drop policy if exists commandes_select on public.commandes;
create policy commandes_select on public.commandes for select to authenticated
using (
  public.is_admin_or_manager()
  or agent_code = public.get_user_agent_code()
  or agent_code = any(public.get_user_agent_codes())
);

-- [DURCI] avant : WITH CHECK (true). Désormais aligné sur le cloisonnement agent.
drop policy if exists commandes_insert on public.commandes;
create policy commandes_insert on public.commandes for insert to authenticated
with check (
  public.is_admin_or_manager()
  or agent_code = public.get_user_agent_code()
  or agent_code = any(public.get_user_agent_codes())
);

drop policy if exists commandes_update on public.commandes;
create policy commandes_update on public.commandes for update to authenticated
using (
  public.is_admin_or_manager()
  or agent_code = public.get_user_agent_code()
  or agent_code = any(public.get_user_agent_codes())
);

drop policy if exists commandes_delete on public.commandes;
create policy commandes_delete on public.commandes for delete to authenticated
using (public.is_admin_or_manager());

-- ---------- clients_order (chaque client ne voit que sa ligne) ----------
drop policy if exists clients_order_select on public.clients_order;
create policy clients_order_select on public.clients_order for select to authenticated
using (
  id = auth.uid()
  or public.is_admin_or_manager()
);

drop policy if exists clients_order_insert on public.clients_order;
create policy clients_order_insert on public.clients_order for insert to authenticated
with check (id = auth.uid());

drop policy if exists clients_order_update on public.clients_order;
create policy clients_order_update on public.clients_order for update to authenticated
using (id = auth.uid() or public.is_admin());

drop policy if exists clients_order_delete on public.clients_order;
create policy clients_order_delete on public.clients_order for delete to authenticated
using (public.is_admin());

-- ---------- produits (catalogue) ----------
-- Lecture publique CONSERVÉE (le proforma charge le catalogue en anonyme).
-- ⚠ Expose la structure de prix/marges (hdht, droits, css) à toute personne
--   ayant la clé anon. Pour restreindre, voir PARTIE E (option 2).
drop policy if exists produits_select_anon on public.produits;
create policy produits_select_anon on public.produits for select to anon
using (true);

drop policy if exists produits_select_auth on public.produits;
create policy produits_select_auth on public.produits for select to authenticated
using (true);

drop policy if exists produits_insert on public.produits;
create policy produits_insert on public.produits for insert to authenticated
with check (public.is_admin_or_manager());

drop policy if exists produits_update on public.produits;
create policy produits_update on public.produits for update to authenticated
using (public.is_admin_or_manager()) with check (public.is_admin_or_manager());

drop policy if exists produits_delete on public.produits;
create policy produits_delete on public.produits for delete to authenticated
using (public.is_admin_or_manager());

-- ---------- profiles ----------
-- Lecture large CONSERVÉE (l'app résout code agent → nom). N'expose ni mot de
-- passe (aucune colonne de ce type) ni donnée client ; seulement l'annuaire
-- interne des agents. Pour restreindre, voir PARTIE E (option 1).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
using (true);

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
using (public.is_admin() or id = auth.uid())
with check (public.is_admin() or id = auth.uid());

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert to authenticated
with check (public.is_admin());

drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles for delete to authenticated
using (public.is_admin());

-- ---------- relances (cloisonnement par code_agent) ----------
drop policy if exists relances_select_policy on public.relances;
create policy relances_select_policy on public.relances for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (p.role in ('admin','manager') or p.agent_code = relances.code_agent)
  )
);

drop policy if exists relances_insert_policy on public.relances;
create policy relances_insert_policy on public.relances for insert to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (p.role in ('admin','manager') or p.agent_code = relances.code_agent)
  )
);

drop policy if exists relances_update_policy on public.relances;
create policy relances_update_policy on public.relances for update to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and (p.role in ('admin','manager') or p.agent_code = relances.code_agent)
  )
);

drop policy if exists relances_delete_policy on public.relances;
create policy relances_delete_policy on public.relances for delete to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);


-- =====================================================
-- PARTIE E — Durcissements OPTIONNELS (décommenter au besoin)
-- =====================================================

-- Option 1 — Restreindre l'annuaire des profils aux admin/manager + soi-même.
-- ⚠ Peut casser l'affichage "code agent → nom" côté agents. Tester d'abord.
-- drop policy if exists profiles_select on public.profiles;
-- create policy profiles_select on public.profiles for select to authenticated
-- using (public.is_admin_or_manager() or id = auth.uid());

-- Option 2 — Retirer l'accès ANONYME au catalogue (protège prix/marges).
-- ⚠ Casse le chargement anonyme du catalogue dans proforma.html : il faudra
--   exiger une session. Ne décommenter qu'après adaptation du front.
-- drop policy if exists produits_select_anon on public.produits;

-- Option 3 — Masquer le CA aux agents CÔTÉ SERVEUR.
-- Le masquage actuel est purement UI (canSeeAll) : la colonne `ca` part quand
-- même au navigateur pour les contacts de l'agent. Approche recommandée :
--   a) créer une vue sans `ca` pour les agents, OU
--   b) exposer `ca` via une fonction/vue réservée admin/manager.
-- Exemple (vue lecture agent, CA masqué sauf admin/manager) :
-- create or replace view public.contacts_agent
-- with (security_invoker = true) as
--   select c.*,
--          case when public.is_admin_or_manager() then c.ca else null end as ca_visible
--   from public.contacts c;
-- (puis faire lire le front via contacts_agent en retirant `ca` du select agent)


-- =====================================================
-- PARTIE F — À faire dans le DASHBOARD (hors SQL)
-- =====================================================
-- 1. Auth > Providers : désactiver l'inscription email publique, ou la soumettre
--    à validation. Créer les comptes agents via une Edge Function service_role.
--    (Sinon toute personne ayant la clé anon peut créer un compte 'agent'.)
-- 2. Auth > Policies : activer "Leaked password protection" (HaveIBeenPwned).
-- 3. Rejouer db/audit_rls.sql sur dlpzxngnphxuvopcxenf pour confirmer l'état.
-- 4. Relancer get_advisors (security) : les alertes ci-dessus doivent disparaître.
-- =====================================================
