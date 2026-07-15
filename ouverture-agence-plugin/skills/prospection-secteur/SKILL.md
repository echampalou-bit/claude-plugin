---
name: prospection-secteur
description: "Construire, clef en main, une base de prospection B2B locale exhaustive et enrichie pour l'ouverture d'une agence sur un NOUVEAU SECTEUR (un ou plusieurs départements), en une passe sur plusieurs métiers à la fois : agences immobilières physiques, mandataires de réseau (Capifrance, IAD, SAFTI, Optimhome…), études notariales, constructeurs de maisons individuelles. Utiliser dès que l'utilisateur veut préparer l'ouverture d'un secteur / point de vente, lister/extraire/enrichir/qualifier/importer des prospects immobiliers sur un territoire, ou lancer une routine de prospection avant l'ouverture — même sans le mot 'skill'. Reprend et généralise la méthode prospection-locale (socle officiel → Google Maps → géocodage BAN → qualification auditée → import), rend la BASE CIBLE paramétrable (Mini pulse par défaut, mais swappable), et GARDE les mandataires comme cible au lieu de les exclure. Couvre le tag secteur, la déduplication multi-métiers, le rapport de run, et le passage de relais vers la veille (skill veille-secteur)."
---

# Prospection de secteur — ouverture d'agence clef en main

Objectif : à partir d'un **secteur** (un ou plusieurs départements + une ville pivot) et d'une liste
de **métiers cibles**, produire une base de prospection **exhaustive, sans faux positifs, enrichie**
(adresse, tél, email, site, note/avis Google, GPS) et **importée proprement** dans le CRM cible,
avec un **tag secteur** — le tout lançable ~2-3 semaines avant l'ouverture.

Cette skill **orchestre** la méthode `prospection-locale` sur PLUSIEURS métiers × PLUSIEURS
départements en une passe. Elle n'invente pas de méthode : elle réutilise les références éprouvées
(voir `references/`) et ajoute l'orchestration, le paramétrage de la base cible, et la prise en
charge des **mandataires comme cible** (et non comme exclusion).

Principe directeur inchangé : **exhaustivité d'abord (source officielle) → enrichissement ensuite
(Google Maps + géocodage) → FILTRAGE AUDITÉ avant import.** Google ne sert jamais de source
d'exhaustivité, seulement à confirmer et enrichir.

---

## Étape 0 — Cadrer le run (toujours commencer ici)

Poser (ou confirmer si déjà donné) :

1. **Secteur** : départements (ex. `58`, `18`) + ville pivot / point de vente (ex. Nevers).
2. **Métiers cibles** parmi : `agences_physiques`, `mandataires`, `notaires`, `constructeurs_mi`.
   (Par défaut : les 4.)
3. **Base cible** : voir le bloc « Connecteur cible » ci-dessous. Par défaut = **Mini pulse**.
4. **Livraison** : import direct via MCP Supabase, OU fichiers CSV/SQL à exécuter par l'utilisateur
   (utile si le connecteur de la base cible n'est pas branché dans la session courante).

Puis créer une **todo-list** (1 entrée par métier × département) et avancer méthodiquement,
en **persistant au fil de l'eau** (un arrêt ne doit rien perdre). Toujours préférer marquer
`a_verifier` plutôt que d'inventer ou de supprimer une donnée incertaine.

---

## Connecteur cible (base swappable) — À LIRE AVANT D'IMPORTER

Toute la méthode est agnostique de la base. Renseigner ce bloc en tête de run ; par défaut =
Mini pulse. Pour changer de destination, ne modifier que ces lignes.

```yaml
# --- PROFIL PAR DÉFAUT : Mini pulse (Aeconomia / Hervé) ---
mcp_supabase: supabase-minipulse          # connecteur MCP à utiliser (écrit : execute_sql/apply_migration)
projet_ref:   gqluidscpcvrivxzfbpm        # get_project_url DOIT renvoyer ceci (sinon mauvais projet)
table_catalogue: leads_imported           # ⚠️ PAS de colonne id ; clé = siret (sinon place_id)
table_etat:      contacts                 # id text = <préfixe> + (siret||place_id) ; state jsonb
prefixes:                                 # 1re lettre de l'id contacts selon le métier
  agences_physiques: A
  mandataires:       A                    # gardés en 'A' + state.subtype='mandataire' (cf. note ci-dessous)
  notaires:          N
  constructeurs_mi:  P                    # promoteurs/constructeurs
  autre:             O
champ_secteur: state->>'sector'           # où écrire le tag secteur (ex. '58', '18', 'Nevers')
etape_nouveau: is_new / progress.isNew    # les fiches fraîches s'affichent à l'étape "Nouveau"
```

> **Vérif obligatoire avant tout write** : appeler `get_project_url` sur le connecteur choisi et
> confirmer qu'il renvoie bien `projet_ref`. L'utilisateur a plusieurs comptes Supabase ; un mauvais
> connecteur = écriture dans la mauvaise base. En cas de doute, s'arrêter et demander.

> **Note mandataires vs catégorie** : Mini pulse n'a que les préfixes A/N/P/O. Les mandataires ne
> sont pas des agences physiques mais restent des cibles → par défaut on les range en `A` avec
> `state.subtype = 'mandataire'` (filtrable côté app). Si l'utilisateur veut une catégorie visuelle
> distincte, le lui proposer (ajout d'un préfixe + libellé dans l'app) plutôt que de décider seul.

---

## Les 4 métiers : socle exhaustif + spécificités

Pour chaque métier, un **socle** différent garantit l'exhaustivité, puis on enrichit tous de la même
façon (Google Maps + BAN).

### 1. Agences immobilières physiques
- **Socle** : SIRENE / établissements actifs, NAF **6831Z** (agences) + **6832A** (gestion/syndic),
  filtrés sur les départements du secteur. Souvent déjà dans le CRM (`leads_imported`).
- **Qualification** : physique vs mandataire vs hors-cible → `references/qualification-agences.sql`.
  Le signal le plus fiable pour démasquer un mandataire = **le domaine du site**.
- Ici on **garde** l'`agence_physique` comme cible n°1.

### 2. Mandataires de réseau (NOUVELLE cible — ne PAS exclure)
- Contrairement à `prospection-locale` (qui les exclut), ici les mandataires **Capifrance, IAD,
  SAFTI, Optimhome, Propriétés Privées, Size/BSK, Megagence, eXp, Keller Williams, Efficity…** sont
  une **cible à part entière**.
- **Socle** : annuaires « trouver un conseiller » de chaque réseau, filtrés par ville/département,
  + Google Maps `conseiller immobilier <ville>`. Détail : `references/mandataires-reseaux.md`.
- Les mandataires détectés par la qualification agences (statut `exclu_mandataire`) sont
  **récupérés** dans cette cible, pas jetés.

### 3. Études notariales
- **Socle** : `annuaire.notaires.fr` = source de vérité (compteur « X offices » = total à atteindre).
  Extraction : `references/notaires-scraper.md`. 1 fiche/office + `contacts[]` (notaires + rôles).

### 4. Constructeurs de maisons individuelles
- **Socle** : SIRENE NAF **4120A** (construction de maisons individuelles) + croisement annuaires de
  fédérations (LCA-FFB / Pôle Habitat, UMF, Maisons de Qualité) + Google Maps. Plus de bruit à
  trier → la RÈGLE D'OR fait le tri. Détail : `references/constructeurs-mi.md`.

---

## Pipeline par (métier × département)

Pour chaque couple, dérouler ces 6 étapes (identiques à `prospection-locale`) :

1. **Socle exhaustif** — la source officielle du métier (ci-dessus).
2. **Enrichissement Google Maps** — note, avis, catégorie (garde-fou anti-homonyme), tél/email/site.
   `references/gmaps-enrichment.md`. Traiter par lots ; persister au fil de l'eau.
3. **Géocodage BAN** — GPS via `api-adresse.data.gouv.fr` (lot CSV). Garder si `result_score ≥ 0.4`,
   sinon repli au centre-commune.
4. **Qualification** — statut par entité (`agence_physique` / `mandataire` / `hors_cible` /
   `a_verifier`).
5. **⚠️ RÈGLE D'OR — audit avant import** (section ci-dessous). Ne JAMAIS supprimer/écraser sur la
   seule foi d'un regex.
6. **Import** dans la base cible, avec `sector` = secteur, catégorie selon `prefixes`, après
   confirmation utilisateur. `references/import-cible.md`.

Après tous les métiers : **déduplication inter-métiers** (une même personne peut apparaître en
agence ET mandataire) + **rapport de run**.

---

## ⚠️ RÈGLE D'OR — Audit avant toute suppression ou import

**Un classement par regex se trompe toujours un peu. Ne jamais supprimer/écraser sur sa seule base.**
Avant un `DELETE` ou un import qui remplace, exécuter ces contrôles :

1. **Faux positifs** — vraies cibles exclues à tort par un mot trop large (le mot vient du nom de la
   COMMUNE ; est la MARQUE de l'agence ; est un ACRONYME). Lister les exclues avec `nom` + `site`,
   repérer un signal fort de cible (`agence`, `immobili`, marque connue) → **rescaper** en tête du
   `CASE` (l'exclusion large est testée avant l'inclusion → sinon elle gagne).
2. **Cohérence département ↔ code postal** — `left(cp,2) = departement` doit être vrai partout ;
   sinon = intrus géographique (homonyme de commune dans un autre département) → écarter.
3. **Ne jamais détruire un travail déjà fait** — avant de remplacer une fiche, vérifier qu'aucune n'a
   de démarche en cours (owner, modifBy, actions[], statut avancé, note). Si oui → **migrer** l'état
   vers la nouvelle fiche, ne pas l'écraser.
4. **Confirmer la suppression destructive** — présenter le décompte exact (supprimées / rescapées /
   à vérifier) et demander le feu vert (AskUserQuestion) AVANT le `DELETE`. Le garde-fou auto bloque
   de toute façon les suppressions de masse non explicitement autorisées.

SQL d'audit prêts : `references/qualification-agences.sql` et `references/import-cible.md`.

---

## Déduplication inter-métiers & rapport de run

- **Dédup** : clé = `nullif(siret,'') || place_id` normalisé, sinon `nom + cp` normalisés. Un même
  réseau à plusieurs bureaux = entrées légitimes distinctes (≠ doublons). Une personne présente en
  `agence_physique` ET `mandataire` → garder la plus qualifiée, tagger l'autre.
- **Rapport** (à livrer en fin de run) : par métier × département — nombre d'entités socle, total
  officiel (si connu), enrichies (note/tél/email), géocodées, statut de qualif, importées,
  `a_verifier` restants. Toujours distinguer les données sûres des `a_verifier`.

---

## Passage de relais → veille automatique

Une fois la base construite et importée, proposer d'installer la **veille de secteur** (skill
`veille-secteur`) : une edge function + cron qui détecte les **nouvelles immatriculations** du
secteur et les insère à l'étape « Nouveau ». C'est le volet headless/continu qui prend le relais du
build supervisé.

---

## Contrôle qualité (avant livraison/import)
- Comparer le nombre d'entités au **total officiel** de la source quand il existe (notaires.fr).
- 0 doublon réel ; téléphones normalisés `0XXXXXXXXX` ; emails nettoyés ; `left(cp,2) = departement`.
- Lister les `a_verifier` et anomalies à l'utilisateur **sans les faire passer pour des données
  sûres**.

## Fichiers de référence
- `references/qualification-agences.sql` — classification SQL 4 statuts + rescues anti-faux-positifs.
- `references/mandataires-reseaux.md` — annuaires des réseaux + extraction (mandataires = cible).
- `references/notaires-scraper.md` — extraction `notaires.fr` (fetch same-origin + DOMParser).
- `references/constructeurs-mi.md` — socle constructeurs MI (SIRENE 4120A + fédérations).
- `references/gmaps-enrichment.md` — extracteur Google Maps + lots + garde-fou catégorie.
- `references/import-cible.md` — connecteur cible paramétrable, géocodage BAN, import/suppression
  sûre (2 tables), migration d'un travail existant, import avec interlocuteurs, tag secteur.
