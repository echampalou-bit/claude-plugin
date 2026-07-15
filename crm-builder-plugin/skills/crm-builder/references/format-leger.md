# Format léger — Outil HTML unique mobile-first

Pour un outil terrain ponctuel ou mono-équipe : un seul fichier `index.html` autonome, utilisable sur mobile comme une app, déployable en 2 minutes. Modèle de référence : l'outil de prospection Tours (Aeconomia).

## Quand l'utiliser
- 1 à 5 utilisateurs, données < ~500 fiches
- Besoin immédiat (tournée de prospection, opération commerciale, suivi d'événement)
- Pas de permissions fines (au plus 2-3 rôles simples gérés côté client)
- Acceptable que la logique soit visible dans le code source

## Anatomie du fichier

```
index.html
├── <head>
│   ├── meta viewport + apple-mobile-web-app (rendu plein écran iOS)
│   ├── CDN : Leaflet (cartes), Google Fonts
│   └── <style> CSS complet avec variables :root
├── <body>
│   ├── header sticky (logo, progression)
│   ├── tabs / vues (jours de tournée, liste, carte, stats)
│   ├── bottom sheet (fiche détail, actions)
│   └── bottom nav fixe (safe-area-inset-bottom)
└── <script>
    ├── const DATA = {...}        ← données embarquées (générées en amont)
    ├── état local "progress"     ← mutations utilisateur
    ├── sync Supabase (optionnel) ← pattern key-value, voir ci-dessous
    └── rendu + interactions vanilla JS
```

## Patterns clés (issus du modèle de référence)

### Données embarquées + état séparé
- `DATA` = le référentiel figé (prospects extraits, organisés par catégorie/collection)
- `progress[id]` = les mutations (statut, notes, actions, température, KO…) stockées à part
- `field(id, f)` lit d'abord `progress`, fallback sur `DATA` (seed) — permet de régénérer DATA sans perdre le travail terrain

### Mutations = log d'actions horodaté
Chaque action utilisateur pousse `{kind, comment, date, by, at}` dans un tableau `actions` par fiche. C'est ce qui rend l'outil exploitable ensuite (export, reporting). Ne jamais écraser, toujours empiler.

### Sync multi-appareils via Supabase en key-value
Pas besoin de schéma relationnel : une table `kv (key text primary key, value jsonb, updated_at)`.
- `kvSet(progress)` après chaque mutation (try/catch silencieux — l'outil marche offline)
- `kvGet()` au chargement + polling léger ou bouton refresh
- Last-write-wins assumé : acceptable à 2-4 utilisateurs, le préciser à l'utilisateur

### Rôles simples côté client
`currentRole` ('courtier'/'directeur'/'admin') sélectionné à l'ouverture, fonctions `isStaff()` pour masquer des actions. Ce n'est PAS de la sécurité — uniquement du confort d'interface. Si la confidentialité compte → format app.

### Export CSV natif
Toujours inclure un export : BOM `\ufeff` + séparateur `;` (Excel FR) + `Blob` + lien téléchargement. C'est la porte de sortie des données vers le CRM principal.

### Mobile-first strict
- `max-width` ~560px centré, gros touch targets (≥44px)
- Bottom sheet pour les fiches (transform translateY, transition)
- `env(safe-area-inset-bottom)` partout où un élément est fixé en bas
- Sticky header avec backdrop-filter

## Génération du DATA
Le référentiel embarqué est produit en amont (extraction de contacts — voir `extraction-contacts.md`), organisé par collections métier avec un préfixe d'ID par type (`A001` agences, `N001` notaires…) pour router les champs spécifiques.

## Déploiement
- Netlify Drop / Vercel statique / n'importe quel hébergement
- Si Supabase utilisé : clé anon publique uniquement, RLS permissive sur la seule table `kv` (ou policy par préfixe de clé)
- Ajouter à l'écran d'accueil iOS/Android = expérience quasi-app native
