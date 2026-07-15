# Modules IA & patterns UI transverses

Patterns réutilisables pour les fonctions à base d'IA (analyse de documents, scoring) et les composants UI qui reviennent dans tous les CRM.

## Analyse IA de documents (CV, dossiers, courriers)

Architecture en deux plans, dans un module dédié (ex. `lib/cv-analysis.ts`) :

1. **Plan A — extraction texte** : extraire le texte du PDF, l'envoyer au modèle avec la grille d'évaluation → score structuré
2. **Plan B — vision (fallback)** : si l'extraction échoue ou rend un texte pauvre (PDF scanné, mise en page graphique, 2 colonnes), **envoyer le PDF directement au modèle multimodal** (content type `file`, `file_data: data:application/pdf;base64,...`). Les modèles type gpt-4o-mini / Claude lisent le PDF nativement — testé en production.

Règles :
- La sortie est **toujours structurée** (JSON : score global /100 + détail par critère) et la grille de critères est **alignée sur le référentiel métier** existant (grille de compétences, scorecard) — pas une grille inventée par l'IA
- Stocker le résultat en jsonb sur l'entité (ex. `candidates.scorecard`), jamais seulement en texte libre
- Le score IA **assiste** la décision humaine, il ne déclenche jamais d'action automatique (rejet, passage d'étape)

## Scorecard d'évaluation multi-étapes

Pour tout processus d'évaluation séquentiel (recrutement, audit, validation onboarding) :
- Table `evaluations` avec `stage` (int), notes par item (jsonb), `total_score`, `recommendation`, évaluateur, `completed_at`
- ⚠️ **`stage` peut valoir 0** (première étape). Ne jamais tester `if (!stage)` — utiliser `stage == null`. Idem côté SQL : contrainte `stage >= 0`, pas `IN (1..n)`.
- Une évaluation validée est verrouillée, avec un bouton explicite « Modifier l'évaluation » pour la déverrouiller (traçabilité plutôt qu'édition libre)
- La validation de la dernière étape déclenche la transition métier (ex. candidat → recruté → création de compte + démarrage onboarding) via une route API dédiée et nommée (`/api/onboardings/start-from-candidate`)

## Board kanban (pipeline visuel)

Pattern pour tout pipeline drag-and-drop (candidats, prospects, dossiers) :
- Colonne = champ `board_status` (text + CHECK constraint) sur l'entité — distinct du statut d'étape métier (`pipeline_stage`). Les deux coexistent : l'étape mesure la progression, le board organise le travail.
- Couleurs de colonnes distinctes, colonnes resserrées, **barre de défilement horizontale toujours visible**
- **Déplacement vers une colonne "sortie" (sans suite, à suivre) → commentaire OBLIGATOIRE** via pop-up. Le commentaire alimente un journal horodaté avec auteur sur la fiche. Sans cette règle, le board devient un cimetière inexpliqué.
- Le même menu d'actions (⋯) sur chaque carte offre les mêmes transitions que le drag-and-drop (accessibilité mobile)

## Journal de fiche (« commentaire général »)

Sur toute entité suivie dans le temps : un bloc journal **toujours visible en haut de la fiche**, alimenté par (1) les ajouts manuels et (2) les événements automatiques (déplacements de board, changements de statut). Chaque entrée : horodatage + auteur + texte. Stockage simple : colonne text append-only ou table dédiée si volumétrie.

## Emails automatisés — templates en base

Dès qu'un CRM envoie des emails automatisés : **les templates vivent en base** (table `email_templates` : clé, sujet, corps avec variables `{{prenom}}`…), **jamais en dur dans le code**.
- UI : une roue crantée ⚙️ à côté de chaque bouton d'envoi ouvre l'édition du template concerné
- Raison : le métier ajuste les formulations sans déploiement — c'est systématiquement demandé après la mise en prod, autant le construire dès le premier email
- Prestataire d'envoi type : Resend (transactionnel applicatif) ; le SMTP des invitations de compte (auth) est un sujet séparé

## Pièges Supabase côté code

- **Lire la table `users` via le client ADMIN** (`createAdminClient`) dans les routes serveur qui ont besoin du rôle/profil — le client RLS peut masquer la ligne et renvoyer `null` silencieusement, cassant les vérifications de permissions en aval
- Dériver plutôt que dupliquer : si deux champs représentent la même réalité (ex. `role` et `seniority`), un seul est la **source unique**, l'autre est calculé (`seniorityFromRole`) — sinon désynchronisation garantie

---
*Dernière mise à jour : 2026-06-12*
