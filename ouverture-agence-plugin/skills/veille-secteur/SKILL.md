---
name: veille-secteur
description: "Installer une veille automatique headless sur un secteur (département(s)) pour un CRM de prospection : une edge function Supabase + un cron qui détecte les NOUVELLES IMMATRICULATIONS d'entreprises cibles (agences immobilières, mandataires, notaires, constructeurs de maisons individuelles) via l'API publique recherche-entreprises, enrichit le téléphone via Google Places, et insère les nouveaux prospects à l'étape « Nouveau ». Utiliser après le build supervisé (skill prospection-secteur), ou dès que l'utilisateur veut une veille continue / un cron de nouvelles entreprises sur un territoire. Reprend le pattern du 'veille' de Mini pulse et de la veille immatriculations 37. Prévoir un enrichissement téléphone périodique en complément."
---

# Veille de secteur — nouvelles immatriculations (headless)

Volet **automatique et continu** qui prend le relais du build supervisé (`prospection-secteur`).
Une fois la base d'un secteur construite, cette veille détecte chaque semaine les **entreprises
nouvellement immatriculées** dans les métiers cibles du secteur et les pousse à l'étape « Nouveau »
du CRM — sans navigateur, 100 % côté Supabase.

C'est le pattern déjà en place sur Mini pulse (edge function `veille` + cron) et sur la veille
immatriculations du 37. Détail technique : `references/veille-edge-function.md`.

## Étape 0 — Cadrer
- **Base cible** + connecteur : même bloc « Connecteur cible » que `prospection-secteur`
  (par défaut Mini pulse, `supabase-minipulse`, `gqluidscpcvrivxzfbpm`). Vérifier `get_project_url`.
- **Secteur** : département(s) (ex. `58`, `18`).
- **Métiers** → codes NAF à surveiller :
  - agences immobilières : `6831Z` (+ `6832A`)
  - constructeurs MI : `4120A`
  - notaires : `6910Z` (activités juridiques — filtrer « notaire ») ou veille manuelle (rare)
  - mandataires : mal captés par le NAF → surtout via le build supervisé, pas la veille.
- **Fréquence** : hebdomadaire (ex. lundi 7h) ou bimensuelle (1er & 15, 6h) comme Mini pulse.

## Ce que fait la veille (résumé)
1. Interroge `recherche-entreprises.api.gouv.fr` par NAF × département, filtrée sur les entreprises
   **créées depuis la dernière exécution** (curseur de date stocké en base).
2. Dédoublonne contre l'existant (`siret` déjà présent → ignorer).
3. Enrichit le **téléphone** via Google Places (secret `GOOGLE_PLACES_KEY`) quand disponible.
4. **Insère** les nouveaux en `contacts` avec `state.sector = <secteur>`, catégorie selon le NAF,
   et **`is_new = true` / étape « Nouveau »** (badge rouge côté app).

## Installation (via le connecteur cible)
1. `deploy_edge_function` : déployer la fonction `veille-<secteur>` (ou paramétrer la fonction
   `veille` existante avec le secteur). Code : `references/veille-edge-function.md`.
2. Poser le secret `GOOGLE_PLACES_KEY` (Dashboard → Project Settings → Edge Functions → Secrets)
   si l'enrichissement tél est voulu.
3. Créer le **cron** (pg_cron / Supabase scheduled function) : ex. `veille_58_18` chaque lundi 7h.
4. **Test à blanc** : exécuter la fonction une fois manuellement, vérifier le nombre d'insertions et
   qu'aucun doublon n'est créé, avant d'activer le cron.

## Complément : enrichissement téléphone périodique
La veille ne trouve pas toujours le téléphone à l'immatriculation. Prévoir (ou réutiliser) une
routine d'enrichissement tél qui repasse tous les 2-3 jours sur les prospects « Nouveau » sans
téléphone (cf. la tâche planifiée `enrichir-tel-nouveaux-prospects` déjà en place côté AGestion :
même principe, à décliner sur la base cible du secteur).

## Garde-fous
- Ne JAMAIS écraser un téléphone déjà présent ni un travail en cours (mêmes règles que
  `prospection-secteur` / RÈGLE D'OR).
- Curseur de date persistant pour ne pas re-scanner tout l'historique à chaque run.
- `left(cp,2) = departement` sur les insertions (éviter les intrus d'un département voisin).
