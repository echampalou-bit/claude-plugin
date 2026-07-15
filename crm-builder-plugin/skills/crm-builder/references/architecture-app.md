# Architecture app — Next.js + Supabase

Stack de référence (éprouvée en production) :

| Élément | Choix | Note |
|---|---|---|
| Framework | Next.js App Router | Server Components par défaut |
| DB | Supabase (Postgres) | `@supabase/supabase-js` + `@supabase/ssr` |
| Styling | Tailwind CSS | tokens custom : `accent`, `surface`, `ink` |
| UI | shadcn/ui + Lucide React | CVA pour les variantes |
| Cartes | Mapbox GL (ou Leaflet si budget zéro) | transpiler via next.config si besoin |
| Export | XLSX (SheetJS) | export Excel des stats |
| Déploiement | Vercel | crons natifs via vercel.json |

## Structure de dossiers

```
app/
├── (auth)/login/page.tsx
├── (dashboard)/
│   ├── layout.tsx              ← Sidebar + auth guard
│   ├── dashboard/              ← widgets KPI personnalisables
│   ├── <entité>/               ← 1 dossier par module métier
│   │   ├── page.tsx            ← liste (Server Component, fetch initial)
│   │   ├── [id]/page.tsx       ← fiche détail
│   │   └── _components/        ← composants client du module
│   ├── pilotage/               ← KPIs, objectifs
│   ├── parametres/             ← config (admin)
│   └── admin/                  ← users, sync
├── api/
│   ├── <entité>/route.ts           ← GET liste, POST création
│   ├── <entité>/[id]/route.ts      ← GET/PUT/DELETE
│   └── cron/<job>/route.ts         ← jobs planifiés (protégés par secret)
lib/
├── types.ts             ← types métier + NAV_GROUPS + ROUTE_ROLES (source de vérité)
├── permissions.ts       ← profils + capabilities CAN + scopes
├── supabase.ts          ← client serveur (session user)
├── supabase-admin.ts    ← client SERVICE_ROLE (sync/cron uniquement)
├── database.types.ts    ← généré par Supabase, ne pas éditer
└── <source>/sync.ts     ← logique de sync externe
middleware.ts            ← auth guard basé sur ROUTE_ROLES
supabase/migrations/     ← SQL versionné, jamais modifié rétroactivement
CRM_STATE.md             ← documentation vivante du projet
```

## Patterns clés

### Pages : Server Component → Client Component
- `page.tsx` = Server Component : auth, fetch initial Supabase, passe les données
- `_components/XxxClient.tsx` = interactivité (filtres, tri, modals, mutations via fetch vers /api)
- Ne pas requêter Supabase depuis le client pour les données protégées — passer par les routes API qui appliquent le scope

### Permissions (2 niveaux)
```typescript
// lib/permissions.ts
type ProfileKind = 'admin' | 'manager' | 'user';

export function profileKindOf(role: UserRole): ProfileKind { /* mapping */ }

export const CAN = {
  partners_view_all:   (p: ProfileKind) => p === 'admin',
  partners_view_agency:(p: ProfileKind) => p !== 'user',
  partners_modify:     (p: ProfileKind) => p !== 'user',
  settings_manage:     (p: ProfileKind) => p === 'admin',
  // ...
};

export function dataScope(p: ProfileKind): 'all' | 'agency' | 'own' { /* ... */ }
```
Chaque route API : récupérer le user → `profileKindOf` → appliquer `dataScope` au query builder. La sidebar et le middleware lisent `ROUTE_ROLES` dans `lib/types.ts` — une seule source de vérité pour la nav ET la sécurité.

### Navigation par rôles
```typescript
export const NAV_GROUPS = [
  { label: 'Commercial', items: [
    { href: '/prospects', label: 'Prospection', roles: ['admin','manager','user'] },
    ...
  ]},
];
export const ROUTE_ROLES: Record<string, UserRole[]> = { /* middleware */ };
```

### Fichiers critiques (à manipuler avec précaution)
- `lib/types.ts`, `lib/permissions.ts`, `middleware.ts` : une erreur casse l'accès de tout le monde
- `lib/<source>/sync.ts` : un bug crée doublons ou fausses conversions
- `app/(dashboard)/layout.tsx` : un crash casse toutes les pages

### Gotchas serveur Supabase
- **Lire `users` via le client ADMIN** (`supabase-admin.ts`) quand une route serveur a besoin du rôle/profil de quelqu'un d'autre que l'utilisateur courant : le client RLS masque la ligne et renvoie `null` silencieusement → les checks de permissions échouent en aval sans erreur visible
- Les composants/patterns IA et UI transverses (analyse de documents, kanban, journaux de fiche, templates email) sont documentés dans `modules-ia.md`

## Ordre de construction d'un nouveau CRM (chantiers séquentiels)

1. **Socle** : auth Supabase + layout + sidebar + middleware + permissions (vide mais en place)
2. **Module 1** : entité principale (table + migration + API CRUD + liste + fiche)
3. **Interactions & relances** sur le module 1
4. **Import** (CSV) ou **sync externe** (si API métier)
5. **Dashboard + KPIs** (seulement quand il y a des données)
6. **Objectifs, alertes, modules secondaires**

Tester chaque chantier avant d'ouvrir le suivant. Mettre à jour `CRM_STATE.md` à chaque fin de chantier (stack, routes, tables, statut des modules).
