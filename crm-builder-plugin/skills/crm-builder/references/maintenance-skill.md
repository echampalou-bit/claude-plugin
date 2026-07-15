# Maintenance de la skill — protocole de mise à jour

La skill est un capital de patterns. Elle se dégrade si elle n'absorbe pas les apprentissages de chaque nouveau CRM. Ce fichier définit le protocole de mise à jour.

## Déclencheur

L'utilisateur dit (en fin de projet, de chantier, ou quand il a accumulé des apprentissages) :

> « Mets à jour la skill crm-builder avec ce projet »

et fournit (ou pointe vers) : `HANDOFF.md`, `CRM_STATE.md`, et tout autre doc projet pertinent.

## Protocole (à exécuter dans l'ordre)

1. **Lire** les documents fournis intégralement.
2. **Extraire uniquement le généralisable.** Test pour chaque élément : « Est-ce que ce pattern servira dans un CRM pour un AUTRE métier, une AUTRE entreprise, une AUTRE base ? »
   - ✅ Généralisable : un piège technique (client RLS vs admin), un pattern UI (board kanban + commentaire obligatoire), une architecture (templates email en base), un workflow (deploy sans local)
   - ❌ Spécifique : noms de personnes, URLs de prod, project_id Supabase, règles métier propres à l'entreprise, contenus (quiz, grilles)
3. **Classer** chaque pattern vers le bon fichier de référence :
   - Schéma/DB → `schema-supabase.md`
   - Structure app, permissions, pièges code → `architecture-app.md`
   - Outil HTML léger → `format-leger.md`
   - Sync API tierce → `sync-externe.md`
   - Import/extraction → `extraction-contacts.md`
   - KPIs/dashboards → `kpis-pilotage.md`
   - Déploiement/env → `deploiement.md`
   - Workflow de travail, docs vivantes → `workflow-projet.md`
   - Modules IA, patterns UI transverses → `modules-ia.md`
   - Nouveau domaine récurrent (3e occurrence) → créer un nouveau fichier de référence
4. **Intégrer sans gonfler** : fusionner avec l'existant, dédupliquer, reformuler en règle générale (pas en anecdote). Si un fichier dépasse ~200 lignes, le scinder.
5. **Mettre à jour SKILL.md** seulement si le workflow global change (nouvelle étape, nouveau fichier de référence à pointer).
6. **Repackager** : `python -m scripts.package_skill <chemin>/crm-builder <sortie>` (script du skill-creator) et fournir le `.skill` à réinstaller.
7. **Résumer** à l'utilisateur : liste des patterns ajoutés, fichiers modifiés, ce qui a été écarté comme trop spécifique (et pourquoi).

## Règles de qualité

- Une règle = une ligne de contexte sur POURQUOI (les pièges sans cause se font ignorer)
- Préférer les seuils et valeurs calibrés (0.85, 220ms…) aux généralités
- Jamais de secrets, d'URLs réelles, de données personnelles dans la skill
- Versionner mentalement : noter la date de dernière mise à jour en bas de chaque fichier modifié

## Limite connue

L'installation de la version mise à jour est manuelle : l'utilisateur réinstalle le `.skill` dans Paramètres > Capacités > Skills. Il n'existe pas de mise à jour silencieuse — c'est voulu (l'utilisateur valide ce qui entre dans son capital de patterns).
