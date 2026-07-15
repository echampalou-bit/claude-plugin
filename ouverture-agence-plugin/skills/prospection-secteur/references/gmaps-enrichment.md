# Enrichissement Google Maps (Claude in Chrome)

But : récupérer **note, nombre d'avis, catégorie** (et confirmer l'identité) d'une fiche Google,
avec un garde-fou anti-faux-positif. Fonctionne sans CAPTCHA en usage normal.

## Extracteur (inline dans javascript_tool)

```js
(()=>{
  const nm=(document.querySelector('h1')||{}).textContent?.trim()||'';
  let r='',v='',c='';
  const e=[...document.querySelectorAll('span[aria-hidden="true"]')].find(x=>/^\d[.,]\d$/.test(x.textContent.trim()));
  if(e) r=e.textContent.trim();                                   // note ex "4,7"
  const a=[...document.querySelectorAll('[aria-label]')].find(x=>/\d[\d\s ]*avis/i.test(x.getAttribute('aria-label')));
  if(a) v=(a.getAttribute('aria-label').match(/([\d\s ]+)\s*avis/i)||[])[1].replace(/\D/g,''); // nb avis
  const b=document.querySelector('button[jsaction*="category"]');
  if(b) c=b.textContent.trim();                                   // catégorie ex "Notaire" / "Agence immobilière"
  return JSON.stringify({nm,r,v,c});
})()
```

## Boucle par lots (browser_batch)

Pour chaque entité, 3 actions : `navigate` vers
`https://www.google.com/maps/search/<encodeURIComponent(nom + ' ' + adresse + ' ' + cp + ' ' + commune)>`,
`computer wait 2.5s`, `javascript_tool` (l'extracteur ci-dessus). ~6 entités/lot.

Les résultats reviennent dans l'ordre → les mapper aux entités du lot. Accumuler dans une variable
de l'onglet **données** (qui n'est jamais navigué), pas dans l'onglet Google (vidé à chaque navigation) ;
ou accumuler côté assistant et fusionner à la fin.

## Garde-fou anti-faux-positif (RÈGLE D'OR)

N'enregistrer note/avis QUE si :
- `c` (catégorie) correspond au métier visé : contient `notaire`/`notarial` ; ou `agence immobilière`
  (accepter aussi "Association de notaires"). 
- ET `nm` n'est pas `"Résultats"` (Maps a renvoyé une liste), ni `"Sponsorisé"` (annonce), ni vide.

Sinon → `note/avis` vides + flag `a_verifier` (ou `hors_categorie` si la catégorie est clairement
autre : "Agriculteur", "Service de santé au travail", "Agence commerciale", etc.).

Cas typiques détectés grâce à ce garde-fou : homonyme d'un autre commerce, fiche sponsorisée d'un
concurrent, liste ambiguë, mandataire renvoyant la fiche du bureau principal.

## Notes de robustesse
- Si l'onglet Google a été fermé entre deux étapes : `tabs_context_mcp` puis `tabs_create_mcp`.
- Si la fiche met >2,5 s à charger, l'extraction renvoie vide → relancer cette entité (souvent OK
  au 2ᵉ essai, la fiche s'étant chargée depuis).
- Volume : ~1 navigation/entité. Pour 150-300 entités, prévoir le temps ; traiter par
  département et persister au fil de l'eau pour qu'un arrêt ne perde rien.
