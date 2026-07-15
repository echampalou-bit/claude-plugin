# Extraction et import de contacts

Alimenter le CRM en prospects depuis des sources en ligne ou des fichiers. Deux étages : (1) constituer le référentiel, (2) l'importer proprement.

## 1. Sources d'extraction

| Source | Pour quoi | Méthode |
|---|---|---|
| Google Maps / Places | Commerces locaux par catégorie + zone (agences immo, notaires…) | API Places (payante, propre) ou recherche web manuelle assistée |
| Annuaires pro (Pages Jaunes, annuaires d'ordres : notaires, CCI) | Professions réglementées | Recherche structurée + saisie assistée |
| Sites web des cibles | Email, contact direct, équipe | Fetch des pages /contact, /equipe |
| LinkedIn / réseaux | Décideurs | Recherche manuelle (pas de scraping automatisé — CGU) |
| Fichiers existants (Excel de l'équipe, exports d'anciens outils) | Reprise d'historique | Import CSV |

**Cadre légal (B2B France)** : la prospection B2B sur coordonnées professionnelles est licite (intérêt légitime RGPD) si : finalité en rapport avec la profession du contact, information et droit d'opposition simple. Pas de moissonnage massif de données personnelles hors contexte pro. Respecter les CGU des plateformes.

## 2. Normalisation (avant tout import)

- **Téléphones** : format E.164 ou national homogène (`06 12 34 56 78`), supprimer les variantes
- **Noms/enseignes** : trim, casse homogène, supprimer les mentions juridiques parasites (SARL, SAS) dans un champ séparé si utile
- **Adresses** : ville + code postal obligatoires ; `insee_code` si croisement avec données publiques
- **Geocoding** : pour la cartographie, géocoder en batch (API Adresse data.gouv.fr — gratuite pour la France : `https://api-adresse.data.gouv.fr/search/?q=...`) et stocker `latitude/longitude` en dur. Ne jamais géocoder à la volée à l'affichage.
- **Catégorie métier** (`family`) : taxonomie fermée définie avant l'extraction (agence_immo / notaire / promoteur / cgp…)

## 3. Déduplication

Ordre de priorité des clés de rapprochement :
1. `external_id` (si la source en fournit un)
2. `email` exact
3. `phone` normalisé
4. Fuzzy : nom normalisé + code postal (Levenshtein ≥ 0.85)

En cas de doublon à l'import : enrichir la fiche existante (champs vides uniquement), ne pas écraser, logger le conflit.

## 4. Import CSV standard

Format pivot (séparateur `;`, encodage UTF-8 BOM pour Excel FR) :

```
name;family;email;phone;address;city;postal_code;source_acquisition;notes
```

Côté app (format complet) : route `POST /api/prospects/import` + modal `ImportCsvModal` :
- Parse côté client (PapaParse), prévisualisation, mapping de colonnes
- Validation ligne à ligne, rapport d'erreurs (ligne N : téléphone invalide)
- Dédoublonnage serveur avant insert
- `source_acquisition` renseigné automatiquement (nom du fichier ou campagne)

Côté outil léger : le référentiel extrait est transformé en objet `DATA` embarqué dans le HTML (voir format-leger.md), avec IDs préfixés par type.

## 5. Du prospect au pipeline

Un contact importé entre toujours en statut initial (`a_contacter`), assigné à un commercial ou à une zone. L'extraction n'est utile que si la tournée/séquence de contact est planifiée derrière — proposer systématiquement la priorisation (potentiel × proximité) au moment de l'import.
