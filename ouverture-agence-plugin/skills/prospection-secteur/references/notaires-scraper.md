# Extraction notaires.fr (annuaire officiel)

Source de vérité pour les études notariales en activité. Tout se fait **depuis un onglet déjà
sur notaires.fr** (Claude in Chrome), via `fetch()` same-origin + `DOMParser` — pas de
navigation page par page.

## 1. URLs

- Page département : `https://www.notaires.fr/fr/annuaire/<region>/<departement>`
  - Centre-Val de Loire : `.../centre-val-de-loire/{indre-et-loire|loir-et-cher|loiret|cher|eure-et-loir|indre}`
  - La liste complète des départements (avec leur région) est en bas de n'importe quelle page annuaire.
- Listing paginé : `<page-departement>?page=0`, `?page=1`, … (10 offices/page).
- Fiche office : `/fr/office/<slug>` → nom, **tél (`a[href^="tel:"]`)**, **email
  (`a[href^="mailto:"]`)**, site web, notaires (`a[href*="/fr/notaire"]`), adresse.

## 2. Récupérer tous les offices d'un département (à exécuter via javascript_tool)

```js
window.__scrapeDept = async (path) => {
  const offices = new Map();
  for (let p = 0; p < 20; p++) {
    const url = p === 0 ? path : path + "?page=" + p;
    const doc = new DOMParser().parseFromString(await fetch(url).then(r=>r.text()), 'text/html');
    const arts = [...doc.querySelectorAll('article')];
    if (!arts.length) break;
    let added = 0;
    for (const a of arts) {
      const link = a.querySelector('a[href*="/fr/office/"]'); if (!link) continue;
      const href = link.getAttribute('href').split('?')[0];
      if (offices.has(href)) continue;
      const name = link.textContent.trim().replace(/\s+/g,' ');
      let website = '';
      for (const ln of a.querySelectorAll('a[href^="http"]')) {
        try { if (new URL(ln.getAttribute('href')).host !== 'www.notaires.fr') { website = ln.getAttribute('href').split('?')[0]; break; } } catch(e){}
      }
      const lines = a.innerText.split('\n').map(s=>s.trim()).filter(Boolean);
      let cp='', ville='', street='';
      const i = lines.findIndex(l=>/^\d{5}$/.test(l));
      if (i>=0){ cp=lines[i]; ville=lines[i+1]||''; const b=lines.findIndex(l=>/Bureau principal/i.test(l)); street=lines.slice(b>=0?b+1:1, i).join(' '); }
      offices.set(href, { office_id: href.replace('/fr/office/',''), href, name, street, cp, ville, website });
      added++;
    }
    if (added === 0 && p > 0) break;
  }
  const arr = [...offices.values()];
  const normPhone = p => { if(!p) return ''; let x=decodeURIComponent(p).replace(/[ .\-]/g,''); return x.replace(/^\+33/,'0').replace(/^0033/,'0'); };
  const parse = html => {
    const d = new DOMParser().parseFromString(html,'text/html');
    const tel = normPhone((d.querySelector('a[href^="tel:"]')||{}).getAttribute?.('href')?.replace('tel:','')||'');
    const emails = [...new Set([...d.querySelectorAll('a[href^="mailto:"]')].map(a=>a.getAttribute('href').replace('mailto:','').trim().replace(/[.,;]+$/,'')))];
    const notaires = [...new Set([...d.querySelectorAll('a[href*="/fr/notaire"]')].map(a=>a.textContent.trim().replace(/\s+/g,' ')).filter(t=>t.length>2 && !/plus d.?infos/i.test(t)))];
    return { tel, emails, notaires };
  };
  for (let i=0;i<arr.length;i+=8) {            // lots de 8 pour rester sous le timeout (~45s)
    await Promise.all(arr.slice(i,i+8).map(async o => {
      try { const d = parse(await fetch(o.href).then(r=>r.text())); o.phone=d.tel; o.emails=d.emails; o.notaires=d.notaires; } catch(e){ o.error=String(e).slice(0,80); }
    }));
  }
  return arr;
};
"ready";
```

Puis `window.__o37 = await window.__scrapeDept("/fr/annuaire/centre-val-de-loire/indre-et-loire");`
(si un gros département dépasse 45 s, le script finit en arrière-plan — revérifier `window.__o37.length` après une pause).

## 3. Vérifications
- `window.__oXX.length` doit égaler le compteur "X offices" affiché sur la page département.
- `emails` vide ou `phone` vide = champ réellement absent sur la fiche officielle (rare) → enrichir via Google.
- Les emails sont au format officiel `prenom.nom@<id>.notaires.fr` → exploitables en prospection B2B.

## 4. Livraison
Construire le CSV en JS (1 ligne/office, colonne `notaires` jointe par " ; ", + `office_id`) puis
déclencher un téléchargement Blob. Produire aussi un CSV "par-notaire" (1 ligne/notaire) lié par
`office_id`. Voir SKILL.md > "Livraison CSV — pièges".
