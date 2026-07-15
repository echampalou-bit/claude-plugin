# Constructeurs de maisons individuelles (CMI) — socle exhaustif

Pas d'annuaire officiel unique comme `notaires.fr`. On combine SIRENE (exhaustif mais bruité) +
annuaires de fédérations (qualifiant) + Google Maps (confirmation).

## 1. Socle SIRENE (exhaustivité)
- NAF **4120A** = « Construction de maisons individuelles ». Filtrer sur les départements du secteur,
  établissements **actifs**.
- Complément utile selon le territoire : **4120B** (construction d'autres bâtiments) et **4110D**
  (promotion immobilière de logements) — à trier, beaucoup de hors-cible.
- Source : base SIRENE (data.gouv / API `recherche-entreprises`) ou l'export déjà présent dans
  `leads_imported` s'il couvre ces NAF.

```
# via l'API publique recherche-entreprises (sans clé), par département :
https://recherche-entreprises.api.gouv.fr/search?activite_principale=41.20A&departement=58&per_page=25&page=1
# paginer jusqu'à épuisement ; répéter pour 18. Champs utiles : nom, siret, adresse, cp, commune.
```

## 2. Annuaires de fédérations (qualification / notoriété)
Croiser le socle SIRENE avec les annuaires de constructeurs sérieux du territoire :
- **LCA-FFB / Pôle Habitat FFB** — annuaire des constructeurs adhérents (gage de sérieux, CCMI).
- **UMF** (Union des Maisons Françaises) — annuaire adhérents.
- **Maisons de Qualité** — label, annuaire par région.
- Les marques nationales à agences locales (Maisons France Confort/Hexaom, Maisons Pierre, Trecobat,
  Babeau Seguin, Demeures Caladoises, etc.) : garder l'**établissement local** du secteur, pas le
  siège.
→ Un constructeur adhérent/labellisé = cible prioritaire ; présent seulement dans SIRENE = `a_verifier`
  jusqu'à confirmation Google Maps (existence réelle d'une agence/bureau).

## 3. Enrichissement & garde-fou
- Google Maps `constructeur maison <nom> <ville>` → catégorie doit contenir `constructeur` /
  `construction de maisons` / `entreprise de construction`. Sinon `a_verifier`.
- Écarter le bruit fréquent sous 4120A : maçons/artisans « tous corps d'état », rénovation seule,
  agences immobilières de programmes neufs, SCI de portage, auto-entrepreneurs dormants.
- Géocodage BAN sur l'adresse du bureau ; repli centre-commune.

## 4. Import
- Préfixe `P` (promoteurs/constructeurs) + `state.subtype = 'constructeur_mi'` + `sector`.
- Interlocuteur : souvent 1 contact commercial/agence → `contacts[]` si connu.

## Contrôle qualité
- Comparer grossièrement au nombre d'adhérents fédération du département (ordre de grandeur).
- Beaucoup de `a_verifier` est normal ici (SIRENE bruité) → les livrer distinctement, ne pas les
  compter comme cibles sûres.
