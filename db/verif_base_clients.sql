-- ============================================================
-- VÉRIFICATION QUALITÉ — base clients (table public.contacts)
-- À exécuter dans le SQL Editor du projet pro.
-- 2 parties :
--   1) TABLEAU DE BORD : exécute le bloc 1 seul -> compteurs par contrôle
--   2) DÉTAILS : exécute une requête détail à la fois pour lister les fiches concernées
-- Lecture seule : ce script ne modifie RIEN.
-- ============================================================

-- ============== 1) TABLEAU DE BORD (exécuter ce bloc) ==============
SELECT * FROM (
  SELECT 0 AS ordre, 'TOTAL contacts' AS controle, count(*) AS nombre FROM contacts
  UNION ALL SELECT 1,'Sans agent attribué', count(*) FROM contacts WHERE agent IS NULL OR btrim(agent)=''
  UNION ALL SELECT 2,'Code agent inconnu (absent de profiles)', count(*) FROM contacts c
     WHERE agent IS NOT NULL AND btrim(agent)<>''
       AND NOT EXISTS (SELECT 1 FROM profiles p WHERE p.agent_code=c.agent OR c.agent = ANY(p.agent_codes))
  UNION ALL SELECT 3,'Doublons de nom (nom identique)', (
     SELECT COALESCE(sum(n-1),0) FROM (SELECT count(*) n FROM contacts GROUP BY upper(btrim(nom)) HAVING count(*)>1) x)
  UNION ALL SELECT 4,'Doublons d''email', (
     SELECT COALESCE(sum(n-1),0) FROM (SELECT count(*) n FROM contacts WHERE email IS NOT NULL AND btrim(email)<>'' GROUP BY lower(btrim(email)) HAVING count(*)>1) x)
  UNION ALL SELECT 5,'Doublons de téléphone', (
     SELECT COALESCE(sum(n-1),0) FROM (SELECT count(*) n FROM contacts WHERE tel IS NOT NULL AND regexp_replace(tel,'\D','','g')<>'' GROUP BY right(regexp_replace(tel,'\D','','g'),9) HAVING count(*)>1) x)
  UNION ALL SELECT 6,'Email invalide (format)', count(*) FROM contacts WHERE email IS NOT NULL AND btrim(email)<>'' AND email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  UNION ALL SELECT 7,'CP invalide (≠ 5 chiffres)', count(*) FROM contacts WHERE cp IS NOT NULL AND btrim(cp)<>'' AND cp !~ '^[0-9]{5}$'
  UNION ALL SELECT 8,'CP incohérent avec le département', count(*) FROM contacts WHERE cp ~ '^[0-9]{5}$' AND dept IS NOT NULL AND btrim(dept)<>'' AND left(cp,2)<>lpad(dept,2,'0') AND dept !~ '^(2A|2B|97|98|AB|DP)'
  UNION ALL SELECT 9,'Téléphone non normalisé (0… au lieu de +33)', count(*) FROM contacts WHERE (tel ~ '^\s*0') OR (port ~ '^\s*0')
  UNION ALL SELECT 10,'Téléphone douteux (longueur anormale)', count(*) FROM contacts WHERE (tel IS NOT NULL AND btrim(tel)<>'' AND length(regexp_replace(tel,'\D','','g')) NOT BETWEEN 9 AND 13)
  UNION ALL SELECT 11,'Sans téléphone NI portable', count(*) FROM contacts WHERE (tel IS NULL OR btrim(tel)='') AND (port IS NULL OR btrim(port)='')
  UNION ALL SELECT 12,'Sans email', count(*) FROM contacts WHERE email IS NULL OR btrim(email)=''
  UNION ALL SELECT 13,'Sans ville ou sans CP', count(*) FROM contacts WHERE (ville IS NULL OR btrim(ville)='') OR (cp IS NULL OR btrim(cp)='')
  UNION ALL SELECT 14,'Sans géoloc (lat/lon) → exclu des tournées', count(*) FROM contacts WHERE lat IS NULL OR lon IS NULL
  UNION ALL SELECT 15,'Classification hors liste', count(*) FROM contacts WHERE classif IS NOT NULL AND upper(btrim(classif)) NOT IN ('TOP','ACTIF','CLIENT','PROSPECT','INACTIF','AGENT')
  UNION ALL SELECT 16,'Incohérence : CA > 0 mais PROSPECT', count(*) FROM contacts WHERE COALESCE(ca,0)>0 AND upper(btrim(coalesce(classif,'')))='PROSPECT'
  UNION ALL SELECT 17,'CA négatif', count(*) FROM contacts WHERE ca < 0
  UNION ALL SELECT 18,'Nom vide', count(*) FROM contacts WHERE nom IS NULL OR btrim(nom)=''
) t ORDER BY ordre;

-- ============== 2) REQUÊTES DÉTAIL (exécuter une à la fois) ==============

-- 2.1 Doublons de nom (mêmes établissements en double)
-- SELECT upper(btrim(nom)) nom_norm, count(*), string_agg(id::text,', ') ids, string_agg(coalesce(agent,'-'),', ') agents
-- FROM contacts GROUP BY upper(btrim(nom)) HAVING count(*)>1 ORDER BY 2 DESC;

-- 2.2 Doublons d'email
-- SELECT lower(btrim(email)) email, count(*), string_agg(nom,' | ') noms
-- FROM contacts WHERE email IS NOT NULL AND btrim(email)<>'' GROUP BY lower(btrim(email)) HAVING count(*)>1 ORDER BY 2 DESC;

-- 2.3 Doublons de téléphone (par numéro canonique 9 chiffres)
-- SELECT right(regexp_replace(tel,'\D','','g'),9) num, count(*), string_agg(nom,' | ') noms
-- FROM contacts WHERE tel IS NOT NULL AND regexp_replace(tel,'\D','','g')<>'' GROUP BY 1 HAVING count(*)>1 ORDER BY 2 DESC;

-- 2.4 Codes agent inconnus (à corriger ou transférer)
-- SELECT agent, count(*) FROM contacts c WHERE agent IS NOT NULL AND btrim(agent)<>''
--   AND NOT EXISTS (SELECT 1 FROM profiles p WHERE p.agent_code=c.agent OR c.agent = ANY(p.agent_codes))
--   GROUP BY agent ORDER BY 2 DESC;

-- 2.5 Emails invalides
-- SELECT id, nom, email FROM contacts WHERE email IS NOT NULL AND btrim(email)<>'' AND email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$';

-- 2.6 CP invalides
-- SELECT id, nom, cp, ville, dept FROM contacts WHERE cp IS NOT NULL AND btrim(cp)<>'' AND cp !~ '^[0-9]{5}$';

-- 2.7 CP incohérents avec le département
-- SELECT id, nom, cp, dept, ville FROM contacts WHERE cp ~ '^[0-9]{5}$' AND dept IS NOT NULL AND btrim(dept)<>'' AND left(cp,2)<>lpad(dept,2,'0') AND dept !~ '^(2A|2B|97|98|AB|DP)';

-- 2.8 Clients sans géoloc (à géocoder pour apparaître dans les tournées)
-- SELECT id, nom, adresse, cp, ville FROM contacts WHERE (lat IS NULL OR lon IS NULL) AND COALESCE(ca,0)>0 ORDER BY ca DESC;

-- 2.9 CA > 0 mais classés PROSPECT (reclasser ?)
-- SELECT id, nom, ca, classif, agent FROM contacts WHERE COALESCE(ca,0)>0 AND upper(btrim(coalesce(classif,'')))='PROSPECT' ORDER BY ca DESC;

-- 2.10 Téléphones encore en 0… (non +33)
-- SELECT id, nom, tel, port FROM contacts WHERE (tel ~ '^\s*0') OR (port ~ '^\s*0');
