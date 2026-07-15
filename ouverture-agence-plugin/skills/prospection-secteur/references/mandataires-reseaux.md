# Mandataires de réseau — cible à part entière (ne PAS exclure)

Dans `prospection-locale`, les mandataires sont **exclus** (on ne veut que les agences physiques).
Ici c'est l'inverse : ils sont une **cible**. On les collecte volontairement, en plus des agences.

## Qu'est-ce qu'un mandataire de réseau
Agent commercial indépendant rattaché à un réseau national, sans agence physique en vitrine. Le
signal le plus fiable = **le domaine du site** (ou l'URL de la fiche « conseiller ») :

| Réseau | Domaine / indice | Annuaire « trouver un conseiller » |
|---|---|---|
| IAD France | `iadfrance.fr`, `iad-france` | iadfrance.fr → recherche par ville |
| Capifrance | `capifrance.fr` | capifrance.fr/conseillers |
| SAFTI | `safti.fr` | safti.fr → trouver un conseiller |
| Optimhome | `optimhome.com` | optimhome.com |
| Propriétés Privées | `proprietes-privees.com` | site → par département |
| BSK / Size | `bskimmobilier.com` | bsk-immobilier |
| Megagence | `megagence.com` | megagence.com |
| eXp France | `exp-france.com`, `expfrance` | exp-france.com |
| Keller Williams | `kwfrance`, `keller-williams` | kwfrance.com |
| Efficity | `efficity.com` | efficity.com |
| Noovimo, Sextant, Dr House, i-Particuliers, La Lucarne… | domaine réseau | site réseau |

## Extraction (2 voies, complémentaires)

### A. Récupération depuis la qualification agences
Le `references/qualification-agences.sql` classe déjà en `exclu_mandataire` toutes les entités dont
le nom ou le domaine matche un réseau. **Ici on les GARDE** : re-router ce bucket vers la cible
`mandataires` (au lieu de les supprimer). C'est la source la plus rapide si SIRENE/leads_imported
contient déjà des mandataires du secteur.

```sql
-- bascule des mandataires détectés vers la cible (ne rien supprimer) :
select nom, cp, commune, tel, site, note, avis
from leads_imported
where category = 'agence' and departement = any(array['58','18'])
  and lower(coalesce(nom,'')||' '||coalesce(site,'')) ~
      '(iadfrance|\yiad\y|i@d|capifrance|safti|optimhome|proprietes-privees|bskimmobilier|\ybsk\y|megagence|exp[- ]?france|keller[- ]?williams|efficity|noovimo|sextant|drhouse|i-particuliers|alalucarne)';
```

### B. Annuaires des réseaux via Claude in Chrome (exhaustivité par réseau)
SIRENE ne liste pas tous les mandataires (beaucoup en micro-entreprise mal classée). Pour être
exhaustif, passer réseau par réseau sur son annuaire « trouver un conseiller », filtré sur les
villes du secteur (ex. Nevers + communes du 58/18) :
- Naviguer sur l'annuaire du réseau, filtrer par ville/code postal.
- Lire le DOM (`read_page` / `get_page_text`) : nom du conseiller, ville, tél, page perso, note.
- Même **garde-fou** que Google Maps : ne retenir que si la fiche correspond bien à une commune du
  secteur (attention aux conseillers d'un département voisin qui « couvrent » la zone).
- Marquer `source = '<reseau>'` et `statut_qualif = 'mandataire'`.

## Enrichissement & import
- Enrichir comme les autres (Google Maps `conseiller immobilier <nom> <ville>`, géocodage BAN au
  centre-commune si pas d'adresse précise — les mandataires n'ont souvent pas d'adresse pro).
- Import : préfixe `A` + `state.subtype = 'mandataire'` + `state.reseau = '<réseau>'` + `sector`.
  (Voir la note « mandataires vs catégorie » dans SKILL.md : proposer une catégorie visuelle dédiée
  seulement si l'utilisateur le souhaite.)

## Pièges
- **Doublon agence/mandataire** : un mandataire peut aussi apparaître dans SIRENE comme micro-agence.
  Dédup sur `nom + commune` ; garder la fiche mandataire (avec réseau) et fusionner les coordonnées.
- **Couverture floue** : un mandataire basé à Nevers peut couvrir tout le 58 → garder, tag commune de
  résidence. Un mandataire d'un département hors secteur qui « intervient » dans le 58 → `a_verifier`.
- **Volume** : les gros réseaux (IAD, Capifrance, SAFTI) dominent ; les petits complètent. Traiter
  d'abord les 5-6 principaux, puis les autres.
