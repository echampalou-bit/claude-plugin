# Schéma Supabase canonique pour CRM

Schéma de référence éprouvé sur le CRM Aeconomia. Adapter les noms au domaine du projet, mais conserver la structure. Toutes les tables ont `id uuid default gen_random_uuid() primary key`, `created_at timestamptz default now()`, `updated_at timestamptz`.

## Conventions

- Noms de tables : anglais, pluriel, snake_case (`prospects`, `partner_reminders`)
- Statuts et types : enums Postgres, valeurs en snake_case français si le métier est français (`a_contacter`, `entretien_decouverte`)
- Clés étrangères explicites : `agency_id`, `assigned_to` (→ users), `created_by` (→ users)
- Ne jamais modifier une migration déjà appliquée — toujours une nouvelle migration
- Générer `database.types.ts` après chaque migration, ne jamais l'éditer à la main

## Tables cœur

### users
```sql
create table users (
  id uuid primary key references auth.users,
  agency_id uuid references agencies,
  role user_role not null default 'user',
  first_name text, last_name text, email text unique, phone text,
  external_user_id text,          -- id dans le logiciel métier si sync
  hired_at date,
  is_active boolean default true,
  created_at timestamptz default now()
);
```

### agencies (si multi-sites)
```sql
create table agencies (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references agencies,   -- hiérarchie (studio → maison → région)
  name text not null, city text, address text,
  lat double precision, lng double precision,
  stage agency_stage,                    -- prospect/studio/maison/region
  director_id uuid references users,
  opened_at date,
  created_at timestamptz default now()
);
```

### prospects (entité saisie/importée — domaine "acquisition")
```sql
create table prospects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  family text,                -- catégorie métier (agence immo, notaire, promoteur…)
  email text, phone text,
  address text, city text, postal_code text, insee_code text,
  latitude double precision, longitude double precision,
  status prospect_status not null default 'a_contacter',
  assigned_to uuid references users,
  agency_id uuid references agencies,
  source_acquisition text,    -- d'où vient le contact (scraping, salon, reco…)
  contact_count int default 0,
  notes text,
  converted_at timestamptz,
  converted_to_partner_id uuid references partners,
  created_at timestamptz default now()
);
```

### partners (entité synchronisée — domaine "portefeuille")
```sql
create table partners (
  id uuid primary key default gen_random_uuid(),
  name text not null, email text, phone text,
  network text,
  status partner_status default 'actif',
  assigned_to uuid references users,
  agency_id uuid references agencies,
  external_id text unique,        -- id dans le logiciel métier (ex. actelo_prescriber_id)
  last_activity_at timestamptz,   -- dernier apport/lead reçu
  last_synced_at timestamptz,
  sync_hash text,                 -- MD5 des champs clés pour delta sync
  comment text,
  created_at timestamptz default now()
);
```
**Règle d'or** : si `external_id` existe, la fiche se crée UNIQUEMENT via la sync. Pas de bouton "nouveau partenaire" manuel — sinon doublons garantis au prochain sync.

### interactions
```sql
create table interactions (
  id uuid primary key default gen_random_uuid(),
  prospect_id uuid references prospects,   -- ou partner_id selon le domaine
  kind text not null,                      -- appel / rdv / email / visite
  comment text,
  happened_at date not null default current_date,
  created_by uuid references users,
  created_at timestamptz default now()
);
```

### reminders (relances)
```sql
create table reminders (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid references partners,     -- ou prospect_id
  assigned_to uuid references users not null,
  due_date date not null,
  note text,
  is_done boolean default false,
  done_at timestamptz,
  created_by uuid references users
);
```

### targets (objectifs) + target_templates
```sql
create table targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users not null,
  period text not null,            -- '2026-06' ou '2026-Q2'
  metric text not null,            -- 'ca' / 'mandats' / 'rdv'
  target_value numeric not null,
  unique(user_id, period, metric)
);
create table target_templates (
  id uuid primary key default gen_random_uuid(),
  name text, seniority text,       -- junior/confirme/expert
  metrics jsonb not null           -- {ca: 90000, rdv: 20, ...}
);
```

### kpi_snapshots (pré-calcul — voir kpis-pilotage.md)
```sql
create table kpi_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users,
  agency_id uuid references agencies,
  period text not null,
  payload jsonb not null,          -- toutes les métriques de la période
  computed_at timestamptz default now(),
  unique(user_id, agency_id, period)
);
```

### sync_logs
```sql
create table sync_logs (
  id uuid primary key default gen_random_uuid(),
  source text not null,            -- 'actelo', 'simulassur'…
  mode text,                       -- 'full' / 'delta'
  status text not null,            -- running / success / partial / failed
  records_processed int, records_updated int, records_created int,
  error text,
  started_at timestamptz default now(),
  completed_at timestamptz
);
```

### notifications
```sql
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users not null,
  type text, title text not null, body text, link_url text,
  is_read boolean default false,
  created_at timestamptz default now()
);
```

## Enums standards

```sql
create type user_role as enum ('admin','manager','user');  -- ou granulaire si besoin
create type prospect_status as enum
  ('a_contacter','appel_1','appel_2','rdv','froid','chaud','bouillant','a_relancer','ko','converti');
create type partner_status as enum ('actif','a_relancer','froid','ko');
create type agency_stage as enum ('prospect','studio','maison','region','suspendu');
```

## RLS (Row Level Security)

- Activer RLS sur toutes les tables exposées au client
- Pattern : les routes API utilisent le client serveur (`@supabase/ssr`) avec la session utilisateur ; les opérations privilégiées (sync, crons) utilisent `SERVICE_ROLE_KEY` via un client admin séparé (`lib/supabase-admin.ts`) — JAMAIS exposé côté client
- Le filtrage métier fin (scope `all/agency/own`) se fait dans le code serveur via `lib/permissions.ts`, RLS sert de filet de sécurité

## Pièges connus

1. **Doublons de partenaires** : toujours dédupliquer sur `external_id` d'abord, puis fallback fuzzy (nom + ville)
2. **Statuts en texte libre** : interdit. Migration douloureuse garantie.
3. **`updated_at` oublié** : ajouter un trigger `moddatetime` ou le setter dans chaque route PUT
4. **JSONB pour tout** : réservé aux structures vraiment variables (scorecard, payload KPI, permissions). Une colonne requêtée/filtrée = une vraie colonne.
5. **Périodes** : standardiser le format (`YYYY-MM`, `YYYY-Qn`, `YYYY`) dès le départ et créer un helper unique de parsing.
6. **Contraintes CHECK trop strictes sur les étapes** : une étape peut valoir 0 (première étape). Écrire `CHECK (stage >= 0)`, pas `IN (1..n)` — et côté code, tester `== null`, jamais `if (!stage)`.
7. **Champs dérivés dupliqués** : si deux colonnes représentent la même réalité (ex. `role` / `seniority`), une seule est la source unique, l'autre est calculée dans le code. Deux sources = désynchronisation garantie.
8. **Deux statuts qui coexistent** : ne pas confondre l'étape métier (`pipeline_stage`, progression) et l'organisation du travail (`board_status`, colonnes kanban : active / a_suivre / recrute / sans_suite). Les fusionner casse l'un ou l'autre.

---
*Dernière mise à jour : 2026-06-12*
