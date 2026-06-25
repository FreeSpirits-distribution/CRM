-- ============================================================
-- Corrections CP/ville/dept vérifiées sur le web (contrôles 7 & 8)
-- A exécuter dans le SQL Editor du projet pro. Ciblage par nom + signature (sûr).
-- ============================================================

-- BREWDOG PLC : CP AB41 8BX = UK valide, ville manquante -> Ellon
UPDATE public.contacts SET ville='Ellon', region=COALESCE(NULLIF(btrim(region),''),'Royaume-Uni'), updated_at=now()
  WHERE upper(nom)='BREWDOG PLC';

-- CHAIVALLIER : Allemagne, Fuhrweg 10A, 61184 Karben
UPDATE public.contacts SET cp='61184', ville='Karben', region=COALESCE(NULLIF(btrim(region),''),'Allemagne'), updated_at=now()
  WHERE upper(nom)='CHAIVALLIER';

-- RECOLTANT MANIPULANT : 1 Rue Hippolyte Flandrin -> 69001 Lyon
UPDATE public.contacts SET cp='69001', ville='Lyon', dept='69', updated_at=now()
  WHERE upper(nom)='RECOLTANT MANIPULANT' AND cp='690014';

-- Cuistot : CP corrompu (bug import) -> 92130 Issy-les-Moulineaux
UPDATE public.contacts SET cp='92130', ville=COALESCE(NULLIF(btrim(ville),''),'Issy-les-Moulineaux'), dept='92', updated_at=now()
  WHERE upper(nom)='CUISTOT' AND cp LIKE '=%';

-- Caissin : CP corrompu (bug import) -> 67750 Scherwiller
UPDATE public.contacts SET cp='67750', ville=COALESCE(NULLIF(btrim(ville),''),'Scherwiller'), dept='67', updated_at=now()
  WHERE upper(nom)='CAISSIN' AND cp LIKE '=%';

-- Les Tontons Pinard : dept 59 faux -> 08 Rethel
UPDATE public.contacts SET dept='08', ville=COALESCE(NULLIF(btrim(ville),''),'Rethel'),
       adresse=COALESCE(NULLIF(btrim(adresse),''),'10 Place Noiret Chaigneau'), updated_at=now()
  WHERE upper(nom)='LES TONTONS PINARD';

-- Wine Not (44 Rue Nationale, 60800) : ville Angers / dept 49 faux -> Crépy-en-Valois (60)
UPDATE public.contacts SET ville='Crépy-en-Valois', dept='60', updated_at=now()
  WHERE upper(nom)='WINE NOT' AND cp='60800';

-- Fiches modèles / fantômes -> suppression (aucune vraie donnée)
DELETE FROM public.contacts WHERE upper(nom)='PROSPECT' AND upper(coalesce(cp,''))='CODE POSTAL' AND upper(coalesce(adresse,''))='ADRESSE';
DELETE FROM public.contacts WHERE upper(nom)='NAME' AND upper(coalesce(cp,''))='CODE POSTAL';
