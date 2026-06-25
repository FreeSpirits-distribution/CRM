-- ============================================================
-- Migration : infos producteur sur les produits
-- A exécuter dans le SQL Editor du projet pro. Rejouable.
-- ============================================================
ALTER TABLE public.produits ADD COLUMN IF NOT EXISTS producteur  text;
ALTER TABLE public.produits ADD COLUMN IF NOT EXISTS pays        text;
ALTER TABLE public.produits ADD COLUMN IF NOT EXISTS region      text;
ALTER TABLE public.produits ADD COLUMN IF NOT EXISTS description text;
