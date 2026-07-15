---
name: crm-builder
description: "Méthode pour construire des CRM et outils de pilotage commercial (Next.js + Supabase + Vercel/Netlify, ou outil HTML léger mobile-first), réutilisable quel que soit le métier ou l'entreprise. Utiliser SYSTÉMATIQUEMENT dès que l'utilisateur veut créer, faire évoluer ou déployer un CRM, un outil de prospection, un pipeline ou board kanban (recrutement, commercial), un suivi d'apporteurs/prospects/candidats, un dashboard KPI, une base Supabase métier, une analyse IA de documents (CV, dossiers), une sync avec un logiciel externe, ou une extraction de contacts — même sans le mot CRM. L'utiliser aussi pour mettre à jour la skill crm-builder avec les apprentissages d'un projet. Couvre : schéma de données canonique, architecture, permissions par rôles, sync delta avec matching flou, déploiement et crons, import de contacts, modules IA, workflow prod-first."
---

# CRM Builder

Méthode pour construire vite et bien un CRM ou un outil de pilotage commercial, en réutilisant des patterns éprouvés au lieu de tout réinventer à chaque projet.

## Étape 0 — Qualifier le besoin (toujours commencer ici)

Avant d'écrire du code, répondre à ces 5 questions (demander à l'utilisateur si l'info manque) :

1. **Qui utilise l'outil ?** (1 commercial terrain / une équipe / plusieurs agences avec hiérarchie)
2. **Quelles entités ?** (prospects, partenaires/apporteurs, candidats, clients, dossiers…)
3. **Source des données ?** (saisie manuelle / import CSV / extraction en ligne / sync API d'un logiciel métier)
4. **Quels KPIs pilotés ?** (volume, conversion, CA, relances…)
5. **Durée de vie ?** (outil ponctuel pour une opération / plateforme pérenne)

## Étape 1 — Choisir le format

Deux formats, deux philosophies. Le mauvais choix coûte des semaines.

| Critère | Format LÉGER (HTML unique) | Format APP (Next.js + Supabase) |
|---|---|---|
| Utilisateurs | 1-5, pas de gestion de comptes fine | 5+, rôles et permissions |
| Données | < ~500 fiches, 1-2 entités | Multi-entités, volumétrie, historique |
| Sync externe | Non (ou Supabase en simple key-value) | Oui (API métier, crons, delta sync) |
| Délai | 1 journée | 1-4 semaines par module |
| Hébergement | N'importe où (fichier statique, Netlify drop) | Vercel (crons natifs) ou Netlify |
| Exemple type | Tournée de prospection terrain mobile | CRM réseau multi-agences |

- Format léger → lire `references/format-leger.md`
- Format app → lire `references/architecture-app.md` puis `references/schema-supabase.md`

**Règle de doute** : si l'outil risque de durer ou de grossir, partir sur le format app mais en MVP (1 module). Un HTML léger qui grossit devient ingérable.

## Étape 2 — Concevoir le schéma de données

Ne jamais inventer le schéma de zéro. Partir du schéma canonique dans `references/schema-supabase.md` : il contient les tables types (contacts/prospects, partenaires, interactions, rappels, utilisateurs, objectifs, kpi_snapshots, logs de sync), les enums standards, les conventions de nommage et les pièges connus.

Principes non négociables :
- **Pipeline = enum de statuts ordonnés**, jamais du texte libre. Définir le funnel AVANT de coder (ex. `a_contacter → appel_1 → rdv → chaud → converti/ko`).
- **Une entité synchronisée depuis une source externe ne se crée JAMAIS manuellement** dans l'app (intégrité : la source de vérité reste le logiciel métier). Les entités saisies à la main (prospects) et synchronisées (partenaires) sont des domaines distincts, reliés par une conversion explicite.
- **Toute interaction est horodatée et attribuée** (`by`, `at`) — c'est la base de tous les KPIs d'activité.
- Soft delete (`is_active`) plutôt que delete pour les entités référencées.

## Étape 3 — Permissions (format app uniquement)

Pattern à 2 niveaux, détaillé dans `references/architecture-app.md` :
- **Rôles techniques** (granulaire, en base : admin, directeur, courtier, assistant…) mappés vers
- **3 profils fonctionnels** : `admin` (tout) / `manager` (son agence + lecture groupe) / `user` (ses données propres).

Le scope de données (`all` / `agency` / `own`) filtre les requêtes côté serveur, jamais côté client. Centraliser dans un seul fichier `lib/permissions.ts` avec un objet `CAN` de capabilities.

## Étape 4 — Sync externe et matching (si API métier)

Si l'outil se connecte à un logiciel métier (type Actelo), lire `references/sync-externe.md`. Patterns clés :
- Delta sync (`updatedSince` depuis la dernière sync réussie), jamais full sync en routine
- Hash MD5 des champs clés par enregistrement → skip si inchangé
- Rate limiting respecté côté client (sleep entre requêtes)
- Matching flou prospect↔entité externe avec 3 zones : score ≥ 0.85 = auto, 0.6-0.85 = validation manuelle, < 0.6 = ignoré
- Tout loggé dans une table `sync_logs` avec statut `running/success/partial/failed`

## Étape 5 — Extraction et import de contacts

Pour alimenter le CRM en prospects depuis le web ou des fichiers : lire `references/extraction-contacts.md`. Couvre les sources, la normalisation (téléphones, adresses, geocoding), la déduplication, et le format d'import CSV standard.

## Étape 6 — KPIs et pilotage

Lire `references/kpis-pilotage.md` avant de créer un dashboard. Contient : la liste des KPIs commerciaux standards (funnel, CA par source, transfo, relances), le pattern `kpi_snapshots` (pré-calcul périodique plutôt que calcul à la volée), le Health Score d'apporteurs, et le système d'alertes configurables.

## Étape 7 — Déployer

Lire `references/deploiement.md` : checklist Vercel/Netlify, variables d'environnement, protection des crons par secret, migrations Supabase, et erreurs classiques de mise en prod.

## Étape 8 — Modules IA et patterns UI transverses

Pour toute fonction d'analyse IA (CV, documents, scoring), board kanban, journal de fiche, ou emails automatisés : lire `references/modules-ia.md`. Contient le pattern d'analyse de document en deux plans (texte + fallback vision PDF), la scorecard multi-étapes, le board avec commentaire obligatoire, et la règle "templates email en base".

## Discipline de construction (format app)

- **Un chantier à la fois.** Construire et tester un module avant d'en ouvrir un autre. Lancer plusieurs phases en parallèle sans test crée de l'instabilité.
- **MVP d'abord** : 1 entité + son pipeline + 1 vue liste + 1 fiche détail. Le dashboard et les KPIs viennent après les données.
- **Documentation vivante obligatoire** : deux fichiers à la racine du projet — `CRM_STATE.md` (architecture) et `HANDOFF.md` (état de session, décisions, gotchas, file d'attente). Détail et structure type dans `references/workflow-projet.md`. C'est la mémoire du projet entre sessions — les mettre à jour à chaque fin de chantier/session.
- **Cycle de travail** : si l'utilisateur ne maintient pas d'environnement local, suivre le cycle "prod-first" décrit dans `references/workflow-projet.md` (modifs → `npx tsc --noEmit` → commit/push par l'utilisateur → deploy auto → test en prod). Secrets jamais dans le chat.
- Les utilisateurs ne codent pas forcément : toujours donner les commandes terminal exactes à copier-coller (chemins absolus), en français clair, une chose à la fois.

## Mise à jour de la skill (capitalisation)

Cette skill doit absorber les apprentissages de chaque nouveau CRM. Quand l'utilisateur dit « mets à jour la skill crm-builder avec ce projet » (ou fournit un HANDOFF.md / CRM_STATE.md en fin de projet), suivre le protocole de `references/maintenance-skill.md` : extraire les patterns généralisables (jamais le spécifique métier/entreprise), les classer dans les bons fichiers de référence, repackager le `.skill` et le fournir pour réinstallation.

## Sortie attendue

Selon la demande, livrer :
- **Cadrage** : choix de format justifié + schéma de données + plan de chantiers ordonné
- **Code** : module fonctionnel testé, avec migrations SQL Supabase fournies séparément
- **Déploiement** : checklist exécutée + URLs + variables d'env documentées
