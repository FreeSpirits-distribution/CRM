-- ============================================================
-- Migration CRM — Admin avancé (image produit + clients Order)
-- A exécuter dans le SQL Editor du projet pro (dlpzxngnphxuvopcxenf).
-- Rejouable sans risque (IF NOT EXISTS / DROP POLICY IF EXISTS).
-- ============================================================

-- 1) Image produit
ALTER TABLE public.produits ADD COLUMN IF NOT EXISTS image_url text;

-- 2) Blocage + notes clients Order
ALTER TABLE public.clients_order ADD COLUMN IF NOT EXISTS blocked boolean DEFAULT false;
ALTER TABLE public.clients_order ADD COLUMN IF NOT EXISTS notes text;

-- 3) Autoriser admin/manager à AJOUTER un client_order depuis l'Admin
--    (un client ajouté ici n'a pas de compte de connexion tant qu'il ne s'inscrit
--     pas via l'app Order ; c'est une fiche, pas un identifiant)
DROP POLICY IF EXISTS clients_order_insert ON public.clients_order;
CREATE POLICY clients_order_insert ON public.clients_order
  FOR INSERT TO authenticated
  WITH CHECK (id = (select auth.uid()) OR public.is_admin_or_manager());

-- 4) Storage : bucket public pour les images produits
INSERT INTO storage.buckets (id, name, public)
VALUES ('produits', 'produits', true)
ON CONFLICT (id) DO NOTHING;

-- 4b) Policies Storage : lecture publique, écriture réservée admin/manager
DROP POLICY IF EXISTS produits_img_read   ON storage.objects;
DROP POLICY IF EXISTS produits_img_write  ON storage.objects;
DROP POLICY IF EXISTS produits_img_update ON storage.objects;
DROP POLICY IF EXISTS produits_img_delete ON storage.objects;

CREATE POLICY produits_img_read ON storage.objects
  FOR SELECT USING (bucket_id = 'produits');

CREATE POLICY produits_img_write ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'produits' AND public.is_admin_or_manager());

CREATE POLICY produits_img_update ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'produits' AND public.is_admin_or_manager());

CREATE POLICY produits_img_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'produits' AND public.is_admin_or_manager());
