-- Qualification agences immobilières : agence_physique / exclu_mandataire / exclu_hors_cible / a_verifier
-- Sur une table type SIRENE+Google (ex. leads_imported : nom, site, adresse, cp, commune, tel, email, note, avis, departement, category).
-- ⚠️ PostgreSQL : frontière de mot = \y  (et NON \b, qui = backspace). Tester sur des comptages avant export.
-- Le signal le plus fiable pour démasquer un mandataire = le DOMAINE DU SITE (champ site), pas seulement le nom.
-- Les entrées "noms de personne sans mot-clé ni site" doivent être croisées via Google Maps (catégorie) :
--   beaucoup sont de vraies petites agences -> override en 'agence_physique' ; sinon 'exclu_*' ou 'a_verifier'.

WITH base AS (
  SELECT *, lower(coalesce(nom,'') || ' ' || coalesce(site,'')) AS blob
  FROM leads_imported
  WHERE category = 'agence' AND departement IN ('41','45')   -- adapter le périmètre
)
SELECT *,
CASE
  -- (1) Overrides manuels validés via Google Maps (catégorie de la fiche) -- À ADAPTER au territoire :
  -- WHEN departement='45' AND nom IN ('...') THEN 'agence_physique'

  -- (2) Réseaux de mandataires / agents indépendants (nom OU domaine du site) :
  WHEN blob ~ '(propri[eé]t[eé]s?[- ]?priv[eé]es|proprietes-privees|iadfrance|\yiad\y|i@d|bskimmobilier|\ybsk\y|exp[- ]?france|keller[- ]?williams|capifrance|optimhome|safti|megagence|m[eé]gagence|noovimo|sextant|efficity|drhouse|alalucarne|i-particuliers|immo[- ]?r[eé]seau)'
       THEN 'exclu_mandataire'

  -- (3) Hors cible (notaire, HLM/bailleur, copro, gîte, diagnostic, commercial/bureaux, SCI, etc.) :
  WHEN blob ~ '(immonot|notaire|\yhlm\y|h\.l\.m|valloire habitat|\yopac\y|\yicf\y|nouveau logis|pierre et lumi|vallogis|novedis|\ycopr\y|coprop|synd copropriet|\yrés\y|r[eé]sidence|immeuble |jardins de|roses de l|orée de sologne|g[îi]te|domaine|hydromel|ferme de la recette|zapart|hôtel|selectour|voyages|avantage loisirs|2 étangs|château de vieux|centre d.affaires|business center|member|pratikbox|\ycbre\y|entrep[ôo]ts|locaux d.activit|location de bureaux|coordonnateur sps|espace charbonni|diagnostic|expertises?|jt expertises|\yldij\y|courtage|\ysci\y|cœur de village|emera|luxe-et-loire)'
       THEN 'exclu_hors_cible'

  -- (4) Agence physique = mot-clé métier dans le nom, OU possède un site web :
  WHEN nom ~* '(agence|immobili|\yimmo\y|cabinet|century|orpi|lafor[eê]t|guy hoquet|st[eé]phane plaza|nestenn|square habitat|l.adresse|\yera\y|arthurimmo|human|foncia|citya|sergic|transaxia|sotheby|habitat|patrimoine|gestion|\ysyndic\y|c[oô]t[eé] particuliers|pargest|locations?)'
       OR coalesce(site,'') <> '' THEN 'agence_physique'

  ELSE 'a_verifier'
END AS statut_qualif
FROM base
ORDER BY departement, statut_qualif, commune, nom;

-- Pour itérer : remplacer le SELECT final par
--   SELECT statut_qualif, count(*) ... GROUP BY 1
-- puis inspecter les buckets 'a_verifier' et les 'agence_physique' promues uniquement par "site<>''"
-- (vérifier qu'aucun mandataire au domaine non listé n'y a glissé), et compléter les overrides (1).
