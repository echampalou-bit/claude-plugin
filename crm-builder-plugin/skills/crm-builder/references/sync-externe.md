# Sync externe — API métier → Supabase

Pattern pour connecter le CRM à un logiciel métier (Actelo, Simulassur, ou tout SaaS avec API REST). Objectif : le CRM pilote, le logiciel métier reste la source de vérité des entités qu'il possède.

## Principes

1. **Sens unique par défaut** : métier → CRM. L'écriture inverse (créer un lead dans le métier depuis le CRM) passe par des endpoints dédiés et explicites.
2. **Les entités synchronisées ne se créent jamais à la main** dans le CRM (voir schema-supabase.md).
3. **Tout est loggé** dans `sync_logs` : mode, statut, compteurs, erreur.

## Client API

```typescript
// lib/<source>.ts
const BASE = process.env.SOURCE_API_URL;     // ex. https://xxx.actelo.fr/api/v1
const headers = { Authorization: `Bearer ${process.env.SOURCE_API_KEY}` };

// Cache Next.js sur les lectures fréquentes :
fetch(url, { headers, next: { revalidate: 300 } });  // 5 min
```
- Pagination : toujours itérer jusqu'à la dernière page, ne jamais supposer "tout tient en une"
- **Rate limit** : respecter la limite documentée côté client (ex. 5 req/s → `sleep(220ms)` entre appels). Ne pas compter sur le 429.

## Delta sync

```typescript
// lib/<source>/sync.ts
async function sync(mode: 'full' | 'delta') {
  const log = await startLog(mode);                       // status: running
  const since = mode === 'delta' ? await lastSuccessAt() : undefined;
  const records = await fetchAll({ updatedSince: since }); // paginé + rate-limited

  for (const r of records) {
    const hash = md5(keyFields(r));                       // champs métier significatifs
    const existing = await byExternalId(r.id);
    if (!existing)                 await insert(r, hash);
    else if (existing.sync_hash !== hash) await update(existing.id, r, hash);
    // sinon : skip (rien n'a changé)
    await sleep(220);
  }
  await closeLog(log, 'success' | 'partial' | 'failed');
}
```

Le hash MD5 des champs clés évite des updates inutiles (et les triggers/notifications parasites qui vont avec).

## Matching flou (rapprochement prospect ↔ entité externe)

Cas d'usage : un prospect démarché dans le CRM apparaît côté métier (il a envoyé son premier dossier) → il faut le convertir en partenaire sans créer de doublon.

Algorithme de scoring par similarité :
- Distance de Levenshtein normalisée sur le nom/enseigne
- Bonus si `network`, `city`, `postal_code` concordent

**Trois zones de décision (à conserver telles quelles, elles sont calibrées) :**

| Score | Action |
|---|---|
| ≥ 0.85 | Conversion automatique + notification au commercial assigné |
| 0.60 – 0.85 | File "matches incertains" → validation manuelle (page dédiée valider/rejeter) |
| < 0.60 | Aucune action |

Ne jamais auto-convertir sous 0.85 : une fausse conversion pollue les KPIs et détruit la confiance des commerciaux dans l'outil.

## Déclenchement

- **Cron quotidien** (delta) : `/api/cron/<source>-sync` appelé par Vercel Cron, protégé par `CRON_SECRET`
- **Manuel** (admin) : page `/admin/sync-<source>` avec bouton + affichage des logs
- Full sync : uniquement à l'initialisation ou après incident, jamais en routine

## Erreurs classiques

1. Sync full quotidienne → rate limit + lenteur + updates inutiles
2. Matching auto trop permissif → doublons et fausses conversions
3. Pas de table de logs → impossible de diagnostiquer "il manque des partenaires"
4. Clé API dans le code client → toujours en variable d'env serveur, sync via client admin Supabase
5. Sync qui plante à mi-parcours sans statut `partial` → données incohérentes silencieuses
