# Déploiement — Vercel / Netlify

## Choix de plateforme

| Besoin | Vercel | Netlify |
|---|---|---|
| App Next.js complète | ✅ natif | ✅ correct |
| Crons planifiés | ✅ `vercel.json` natif | Scheduled Functions (plus limité) |
| Fichier HTML statique (format léger) | ✅ | ✅ (Netlify Drop = le plus rapide) |
| Recommandation | App → Vercel | Outil léger → Netlify Drop |

## Checklist déploiement app (Vercel)

1. **Variables d'environnement** (dashboard Vercel, jamais committées) :
   - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (publiques)
   - `SUPABASE_SERVICE_ROLE_KEY` (serveur uniquement — fuite = accès total à la DB)
   - `<SOURCE>_API_KEY`, `<SOURCE>_API_URL` (sync métier)
   - `CRON_SECRET` (généré aléatoirement, long)
   - `NEXT_PUBLIC_MAPBOX_TOKEN` si cartographie
2. **Migrations Supabase** appliquées sur le projet de prod AVANT le premier deploy (sinon crash au boot)
3. **Crons** dans `vercel.json` :
```json
{
  "crons": [
    { "path": "/api/cron/source-sync", "schedule": "0 6 * * *" },
    { "path": "/api/cron/recompute-scores", "schedule": "30 6 * * *" },
    { "path": "/api/cron/run-alerts", "schedule": "0 7 * * *" }
  ]
}
```
4. **Protection des crons** — chaque route cron commence par :
```typescript
if (request.headers.get('authorization') !== `Bearer ${process.env.CRON_SECRET}`)
  return new Response('Unauthorized', { status: 401 });
```
(Vercel envoie automatiquement ce header sur les crons configurés.)
5. **Auth Supabase** : ajouter l'URL de prod dans Supabase → Authentication → URL Configuration (redirect URLs), sinon le login boucle
6. **Smoke test post-deploy** : login, une page liste, une mutation, déclencher une sync manuelle, vérifier `sync_logs`

## Environnements

- Local : `.env.local` (ignoré par git) + projet Supabase de dev OU branche Supabase
- Prod : projet Supabase séparé. Ne JAMAIS pointer le dev sur la DB de prod
- Preview deployments Vercel : pointer sur le Supabase de dev par défaut

## Erreurs classiques

1. `SERVICE_ROLE_KEY` préfixée `NEXT_PUBLIC_` → exposée au client. Catastrophique.
2. Migrations oubliées en prod → erreurs "relation does not exist"
3. Crons non protégés → n'importe qui déclenche des syncs/recalculs
4. Redirect URL Supabase manquante → login impossible en prod uniquement
5. Cache Next.js (`revalidate`) qui masque des données fraîches → prévoir un bypass sur les pages temps réel

## Format léger

Netlify Drop (glisser le fichier) ou `vercel --prod` sur un dossier statique. Si Supabase KV utilisé : seule la clé anon dans le HTML, RLS limitée à la table `kv`.
