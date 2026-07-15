# Import dans la base cible (paramétrable) + géocodage BAN + suppression sûre

Généralise l'import de `prospection-locale` (qui visait Mini pulse en dur) à une **base cible
paramétrable** via le bloc « Connecteur cible » de SKILL.md. Par défaut = Mini pulse.

## 0. Vérifier la cible AVANT tout write
```
get_project_url  (sur le connecteur `mcp_supabase` choisi)  →  DOIT == projet_ref
```
Si ça ne correspond pas : STOP, on est sur la mauvaise base (l'utilisateur a plusieurs comptes).
Le connecteur cible **écrit** (execute_sql / apply_migration : ALTER/UPDATE/DELETE). Le garde-fou
auto bloque les DELETE de masse et les changements RLS/sécurité non explicitement autorisés → faire
confirmer par l'utilisateur, puis exécuter.

## 1. Géocodage BAN (avant import, pour la carte / les tournées)
API officielle gratuite, en lot :
```bash
curl -s -X POST -F data=@in.csv -F columns=adresse -F columns=ville -F postcode=code_postal \
  "https://api-adresse.data.gouv.fr/search/csv/" -o out.csv
# out.csv ajoute : longitude, latitude, result_score, result_city, result_type
```
Garder les coords si `result_score >= 0.4` ; sinon repli au centre-commune (géocoder la ville seule).
`result_city` donne un joli libellé de commune (bonne casse).

## 2. Schéma Mini pulse (profil par défaut)
- **`leads_imported`** = catalogue chargé au runtime. ⚠️ **PAS de colonne `id`** : la clé est
  `siret` (sinon `place_id`). Pour classer : `UPDATE ... SET statut_qualif = CASE ... END WHERE ...`
  direct (jamais de self-join sur `id`).
- **`contacts`** = état/progression. `id` text = **préfixe + (siret||place_id)**. Préfixes :
  `A` agences, `N` notaires, `P` promoteurs/constructeurs, `O` autre, `C` comités.
  `state` (jsonb) = statut, modifBy, actions[], **contacts[] (interlocuteurs)**, daterdv, notes,
  **sector**, subtype, reseau.
- **Tag secteur** : écrire `sector` dans `state` à l'import (ex. `'58'`, `'18'`, ou `'Nevers'` selon
  la granularité voulue). C'est ce qui rattache la fiche au secteur d'ouverture et pilote `canEdit`.
- **Étape « Nouveau »** : les fiches fraîches issues de la veille passent par `is_new` / `progress.isNew`.
  Un import de build initial n'a pas besoin d'être « Nouveau » (statut par défaut « À contacter »/
  « À démarcher »), sauf demande contraire.

## 3. Import type (upsert idempotent)
Construire un `INSERT ... ON CONFLICT DO UPDATE` (ou apply_migration) qui n'écrase PAS un travail
existant (cf. RÈGLE D'OR §3). Squelette :
```sql
insert into contacts (id, category, nom, adresse, cp, ville, tel, email, site, lat, lon, state)
values (
  'A'||coalesce(nullif(:siret,''), :place_id),      -- préfixe selon métier
  'agence', :nom, :adresse, :cp, :ville, :tel, :email, :site, :lat, :lon,
  jsonb_build_object('sector', :secteur, 'subtype', :subtype, 'reseau', :reseau,
                     'note', :note, 'avis', :avis, 'source', :source, 'statut', 'À démarcher')
)
on conflict (id) do update set
  tel   = coalesce(nullif(excluded.tel,''),   contacts.tel),
  email = coalesce(nullif(excluded.email,''), contacts.email),
  site  = coalesce(nullif(excluded.site,''),  contacts.site),
  lat   = coalesce(excluded.lat, contacts.lat),
  lon   = coalesce(excluded.lon, contacts.lon),
  -- ne touche PAS state.statut / actions / owner déjà travaillés :
  state = contacts.state
          || jsonb_build_object('sector', coalesce(contacts.state->>'sector', excluded.state->>'sector'));
```
Adapter `category` / préfixe / `subtype` selon le métier (agences_physiques, mandataires→subtype,
notaires→N, constructeurs_mi→P).

## 4. Import avec interlocuteurs (notaires, agences multi-agents)
1 fiche/entité + un tableau `state.contacts[]` (un objet par interlocuteur : `{nom, role}`). Côté app,
`getContacts()` retombe sur les interlocuteurs du record si la progression n'en a pas encore (donc
éditables ensuite). Pour les études : notaires + rôles (associé/salarié), même ordre.

## 5. Suppression sûre (2 tables) — seulement après la RÈGLE D'OR
Supprimer une entité = supprimer dans `leads_imported` ET `contacts`
(`id = préfixe + coalesce(nullif(siret,''), place_id)`), après :
- audit faux positifs (rescues en tête du CASE),
- cohérence `left(cp,2) = departement`,
- **migration** de tout travail en cours vers la fiche conservée,
- confirmation utilisateur (décompte exact) via AskUserQuestion.

## 6. Livraison sans connecteur branché
Si le connecteur `mcp_supabase` de la base cible n'est pas actif dans la session courante (ex. on est
côté AGestion mais la cible est Mini pulse) : **ne pas retranscrire à la main**. Livrer soit un CSV
prêt à « Import » dans l'app, soit un fichier `.sql` testé que l'utilisateur exécute dans l'éditeur
SQL Supabase du bon projet. Toujours indiquer clairement le `projet_ref` cible.

## Schéma CSV recommandé (livraison / audit)
`id_stable, departement, secteur, metier, nom, adresse, code_postal, commune, telephone, email, site,
note_google, avis_google, lat, lon, statut_qualif, reseau, [notaires, statuts], source, date_extraction`
Toujours : clé stable (SIRET/place_id/slug) ; dater chaque ligne ; marquer les champs manquants et
`a_verifier`.
