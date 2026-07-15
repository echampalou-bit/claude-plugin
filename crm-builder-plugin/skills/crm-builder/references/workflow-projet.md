# Workflow projet — documentation vivante & cycle de travail

Patterns d'organisation du travail entre l'utilisateur (souvent non-technicien), Claude, et l'infrastructure. Indépendants du métier du CRM.

## Les deux documents vivants (à créer dès le jour 1)

| Document | Rôle | Mis à jour |
|---|---|---|
| `CRM_STATE.md` | **Architecture** : stack, structure de navigation, statut des modules, tables, routes API, fichiers critiques | À chaque fin de chantier |
| `HANDOFF.md` | **État de session** : repères techniques (URLs, IDs projet), workflow en vigueur, décisions structurantes, gotchas découverts, file d'attente priorisée | À chaque fin de session de travail |

Convention de reprise : en début de nouvelle conversation, l'utilisateur dit « Lis HANDOFF.md » et le travail repart à jour. C'est la mémoire inter-sessions du projet — sans elle, chaque session repart de zéro et réintroduit des bugs déjà corrigés.

Structure type de HANDOFF.md : Repères techniques → Workflow → Préférences de travail → Décisions structurantes → Ce qui est construit & déployé → Changements DB récents → Gotchas connus → File d'attente → Pour repartir vite.

## Cycle de travail "prod-first" (sans environnement local)

Éprouvé avec un utilisateur non-technicien qui ne veut pas maintenir un environnement local :

1. Claude modifie les fichiers du repo
2. Vérification statique : `npx tsc --noEmit` (filet de sécurité minimal sans `npm run dev`)
3. **L'utilisateur** commit/push (GitHub Desktop) — jamais Claude sans validation
4. Vercel déploie automatiquement à chaque push sur `main`
5. Test directement sur l'URL de prod, guidé pas à pas par Claude

Conditions pour que ce soit acceptable : outil interne (pas de clients externes), équipe restreinte, et `tsc` systématique avant chaque push. Si l'app devient critique → réintroduire un environnement de préprod (preview deployments Vercel + Supabase de dev).

**Base de données en mode prod-first** : les migrations s'appliquent directement sur Supabase (dashboard ou MCP), ET un fichier `.sql` est posé dans `supabase/migrations/` pour la trace. Assumer que **la vérité est en base**, pas dans `schema.sql` du repo — le noter dans HANDOFF.md.

## Règles avec un utilisateur non-technicien

- Une chose à la fois, testée, avant la suivante. Expliquer COMMENT tester (clic par clic).
- Commandes terminal : toujours le chemin absolu (le shell peut réinitialiser son dossier courant), toujours copiables-collables telles quelles.
- **Secrets : jamais dans le chat.** L'utilisateur les saisit lui-même dans Vercel (et `.env.local` le cas échéant). Claude référence les variables par leur nom uniquement.
- Commit/push : uniquement quand l'utilisateur a validé le test.

## Import de données depuis des plateformes tierces (sans API)

Quand une plateforme source (job board, annuaire) n'offre pas d'API exploitable : une **extension Chrome maison** d'import 1-clic est un pattern viable — elle lit la page ouverte et poste vers une route API de l'app. Points d'attention : normaliser l'URL de l'app dans les réglages de l'extension (ajouter `https://` automatiquement), authentifier la route d'import, et rester dans le cadre des CGU de la plateforme.

---
*Dernière mise à jour : 2026-06-12*
