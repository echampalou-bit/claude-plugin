# Edge function `veille` + cron — pattern de référence

Squelette d'une edge function Supabase (Deno) qui détecte les nouvelles immatriculations d'un secteur
et les insère à l'étape « Nouveau ». Adapté du `veille` de Mini pulse et de la veille immatriculations
du 37. À déployer via `deploy_edge_function` sur le connecteur cible.

## Paramètres (en tête de fonction ou via secrets)
```ts
const SECTEUR   = { departements: ["58", "18"], label: "58" };
const NAF = {
  "6831Z": { cat: "agence",       prefixe: "A" },
  "6832A": { cat: "agence",       prefixe: "A" },
  "4120A": { cat: "constructeur", prefixe: "P" },
};
const PLACES_KEY = Deno.env.get("GOOGLE_PLACES_KEY"); // optionnel (enrichissement tél)
```

## Boucle principale
```ts
// 1. curseur : dernière date scannée (table meta ou state), défaut = J-8
const since = await getCursor();                       // ex. "2026-07-08"
for (const dep of SECTEUR.departements) {
  for (const [naf, meta] of Object.entries(NAF)) {
    let page = 1;
    while (true) {
      const url = `https://recherche-entreprises.api.gouv.fr/search`
        + `?activite_principale=${naf}&departement=${dep}`
        + `&per_page=25&page=${page}`;
      const { results, total_pages } = await fetch(url).then(r => r.json());
      for (const e of results) {
        const created = e.date_creation;               // filtrer côté code : created >= since
        if (!created || created < since) continue;
        const siret = e.siege?.siret ?? e.siren;
        if (await exists(siret)) continue;              // dédup : déjà en base
        const cp = e.siege?.code_postal ?? "";
        if (cp.slice(0,2) !== dep) continue;            // intrus géo
        let tel = "";
        if (PLACES_KEY) tel = await placesPhone(e.nom_complet, e.siege, PLACES_KEY);
        await insertContact({
          id: meta.prefixe + siret, category: meta.cat,
          nom: e.nom_complet, adresse: e.siege?.libelle_voie, cp, ville: e.siege?.libelle_commune,
          tel, state: { sector: SECTEUR.label, statut: "Nouveau", is_new: true, source: "veille" },
        });
      }
      if (page >= total_pages) break;
      page++;
    }
  }
}
await setCursor(today());                               // avancer le curseur
```

## Insertion (ne rien écraser)
`insert ... on conflict (id) do nothing` — la veille ne met à jour aucune fiche existante, elle
n'ajoute que du nouveau. L'enrichissement/mise à jour est fait ailleurs (routine tél, build).

## Cron
```sql
-- pg_cron : chaque lundi 7h (Europe/Paris ≈ 5h UTC l'été, 6h l'hiver — ajuster)
select cron.schedule(
  'veille_58_18', '0 5 * * 1',
  $$ select net.http_post(
       url := 'https://<projet_ref>.functions.supabase.co/veille-58-18',
       headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_key'))
     ); $$
);
```
Alternative : Supabase Scheduled Functions (UI). Mini pulse utilise un cron bimensuel `1,15 * * 6h`.

## Enrichissement tél via Google Places (optionnel)
```ts
async function placesPhone(nom, siege, key) {
  const q = encodeURIComponent(`${nom} ${siege?.libelle_commune ?? ""}`);
  const find = await fetch(`https://maps.googleapis.com/maps/api/place/findplacefromtext/json`
    + `?input=${q}&inputtype=textquery&fields=place_id&key=${key}`).then(r=>r.json());
  const pid = find.candidates?.[0]?.place_id; if (!pid) return "";
  const det = await fetch(`https://maps.googleapis.com/maps/api/place/details/json`
    + `?place_id=${pid}&fields=formatted_phone_number&key=${key}`).then(r=>r.json());
  return (det.result?.formatted_phone_number ?? "").replace(/[ .]/g,"");
}
```

## Test à blanc avant d'activer le cron
1. Invoquer la fonction une fois (curseur J-30 pour avoir des résultats).
2. Vérifier : nb d'insertions cohérent, 0 doublon (`id` unique), `left(cp,2)` = département,
   fiches bien à l'étape « Nouveau ».
3. Remettre le curseur à jour, puis activer le cron.
