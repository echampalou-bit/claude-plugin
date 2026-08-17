---
name: aeconomia-data-analyst
description: >
  Skill spécialisé pour l'analyse des données commerciales d'Aeconomia (fichiers dossiers.xlsx
  issus de Global Courtage). À utiliser SYSTÉMATIQUEMENT dès que Dimitri charge un fichier de
  dossiers, demande un CA, une analyse par commercial, par apporteur, ou toute statistique
  commerciale. Impose un protocole d'audit obligatoire AVANT tout calcul et une vérification
  transparente APRÈS, pour garantir la reproductibilité des chiffres entre conversations.
---

# Aeconomia — Data Analyst Skill

## Contexte métier
- **Société** : Aeconomia, courtage en crédit immobilier (IOBSP), Orléans
- **Source** : Export Global Courtage CRM → fichier `.xlsx`, onglet "Worksheet"
- **Dirigeant** : Dimitri TOULON (exclu des analyses commerciales — voir §Commerciaux)

---

## RÈGLES FONDAMENTALES (décidées par Dimitri)

| Paramètre | Règle |
|---|---|
| **Définition du CA** | `Honos. prévus` + `Comm. prévue` (les deux colonnes, toujours) |
| **Périmètre dossiers** | Tous les dossiers du fichier, sans exception ni filtre sur l'étape |
| **Catégorie Aeconomia** | Toute valeur contenant le mot `AECONOMIA` (insensible à la casse) |
| **Autres apporteurs stratégiques** | Liste évolutive — afficher les valeurs inconnues à chaque analyse |
| **Apporteur vide** | Classé en catégorie `Non renseigné` (jamais exclu du CA total) |
| **Commerciaux** | Exclure `Dimitri TOULON` des tableaux commerciaux (dirigeant, pas commercial) |
| **Période** | Définie par le fichier exporté — filtrage par mois/trimestre possible si demandé |
| **Format de sortie** | Excel si analyse complète · Réponse chat si question rapide |

---

## PROTOCOLE OBLIGATOIRE — Exécuter dans l'ordre strict

### ÉTAPE 1 — Audit pré-calcul (toujours afficher à Dimitri)

```python
import pandas as pd
df = pd.read_excel('fichier.xlsx')

print(f"Lignes brutes            : {len(df)}")
print(f"Honos. prévus NaN        : {df['Honos. prévus'].isna().sum()}")
print(f"Comm. prévue NaN         : {df['Comm. prévue'].isna().sum()}")
print(f"Comm. prévue = 0         : {(df['Comm. prévue'] == 0).sum()}")
print(f"Apporteurs vides         : {(df['Apporteurs'].fillna('').str.strip() == '').sum()}")
print(f"Commercial NaN           : {df['Commercial'].isna().sum()}")
print(f"Dossiers Dimitri TOULON  : {(df['Commercial'] == 'Dimitri TOULON').sum()}")
```

Afficher ce bloc dans la réponse avant tout calcul.

---

### ÉTAPE 2 — Préparation des données

```python
# CA
df['CA'] = df['Honos. prévus'] + df['Comm. prévue'].fillna(0)

# Normalisation apporteurs
df['App_norm'] = df['Apporteurs'].fillna('').str.strip().str.upper()

# Apporteurs vides → 'NON RENSEIGNÉ'
df.loc[df['App_norm'] == '', 'App_norm'] = 'NON RENSEIGNÉ'

# Périmètre commerciaux (exclure Dimitri TOULON)
df_com = df[df['Commercial'] != 'Dimitri TOULON'].copy()
```

---

### ÉTAPE 3 — Catégorisation des apporteurs

#### Catégorie Aeconomia (logique dynamique)
```python
df['cat_aeconomia'] = df['App_norm'].str.contains('AECONOMIA', na=False)
```

#### Autres apporteurs stratégiques (liste de référence à jour au 01/04/2026)

| Catégorie | Mots-clés / valeurs normalisées |
|---|---|
| **Reco du site** | `RECO DU SITE` |
| **Devisprox** | `DEVISPROX` |
| **Google Ads** | `GOOGLE ADS` |
| **CE Dior** | contient `CE DIOR` |
| **Cyberpret** | `CYBERPRET` |

> ⚠️ **Ces catégories sont évolutives.** À chaque analyse, afficher les valeurs non classifiées
> (ni dans une catégorie stratégique, ni `NON RENSEIGNÉ`, ni `AECONOMIA`) pour que Dimitri
> puisse décider si elles doivent rejoindre une catégorie existante ou en créer une nouvelle.

```python
# Détection des valeurs non classifiées
mask_connu = (
    df['App_norm'].str.contains('AECONOMIA', na=False) |
    df['App_norm'].str.contains('CE DIOR', na=False) |
    df['App_norm'].isin(['RECO DU SITE', 'DEVISPROX', 'GOOGLE ADS', 'CYBERPRET', 'NON RENSEIGNÉ'])
)
inconnus = df[~mask_connu]['App_norm'].value_counts()
if len(inconnus) > 0:
    print("⚠️ VALEURS APPORTEURS NON CLASSIFIÉES — à valider avec Dimitri :")
    print(inconnus.to_string())
```

---

### ÉTAPE 4 — Filtrage temporel (si demandé)

Le fichier exporté correspond déjà à la période voulue par défaut.
Si Dimitri demande un filtre par mois ou trimestre, lui demander quelle colonne date utiliser :

- `Accord banque choisie` → date d'accord (production en cours)
- `Signature notaire` → date de vente définitive (CA encaissable)

```python
df['date_ref'] = pd.to_datetime(df['Signature notaire'], errors='coerce')
# Filtre mois : df[df['date_ref'].dt.month == M]
# Filtre trimestre : df[df['date_ref'].dt.quarter == Q]
```

---

### ÉTAPE 5 — Bloc de vérification post-calcul (toujours afficher)

```
✅ VÉRIFICATION DES DONNÉES
────────────────────────────────────────────────────
Fichier analysé         : [nom + date]
Lignes brutes           : [N]
Dossiers Dimitri exclus : [N]  → périmètre commercial : [N]
Apporteurs vides        : [N]  → classés "Non renseigné"
Valeurs non classifiées : [N apporteurs distincts] ← liste ci-dessus
CA total brut           : [X €]  (Honos. [X €] + Comm. [X €])
CA périmètre commercial : [X €]
────────────────────────────────────────────────────
```

---

## FORMAT DE SORTIE

### Question rapide (ex : "quel est le CA de Robin ?")
→ Réponse directe dans le chat + bloc ✅ VÉRIFICATION condensé

### Analyse complète
→ Fichier Excel avec 3 onglets :

| Onglet | Contenu |
|---|---|
| `Vue d'ensemble` | CA par apporteur stratégique + % CA total + ligne Non renseigné |
| `CA par commercial` | Tableau croisé commercial × apporteur (CA €) |
| `% par commercial` | Tableau croisé commercial × apporteur (% du CA du commercial) |

Couleurs : fond `#0A0A0A` pour les en-têtes, vert `#B8F000` pour les totaux, beige `#F7F5F2` pour les lignes alternées. Police Arial.

---

## CHIFFRES DE RÉFÉRENCE CERTIFIÉS (fichier 01/04/2026)

À utiliser pour vérifier la cohérence des calculs sur le même fichier.

| Métrique | Valeur certifiée |
|---|---|
| Dossiers bruts | 267 |
| Dossiers Dimitri TOULON | 1 |
| Périmètre commercial | 266 |
| CA total brut | 986 317,51 € |
| CA périmètre commercial | 984 192,51 € |
| **Aeconomia** (contains) | 50 dossiers — 199 254,74 € |
| Reco du site | 19 dossiers — 69 467,59 € |
| CE Dior (contains) | 9 dossiers — 32 229,63 € |
| Devisprox | 3 dossiers — 9 907,24 € |
| Cyberpret | 2 dossiers — 6 950,00 € |
| Google Ads | 1 dossier — 5 503,95 € |
| Non renseigné | 10 dossiers |
| **Total apporteurs ciblés** | **84 dossiers — 323 313,15 €** |
| **Part CA apporteurs ciblés / CA commercial** | **32,8%** |

---

## SOURCES DE DIVERGENCE HISTORIQUES — Rappel

| Cause | Ancienne logique (fausse) | Nouvelle logique (correcte) |
|---|---|---|
| Périmètre Aeconomia | Liste figée de 12 valeurs | `contains('AECONOMIA')` |
| Espaces trailing | Filtre direct | `.str.strip()` obligatoire |
| NaN Comm. prévue | Propagation silencieuse | `.fillna(0)` obligatoire |
| Caractère À accentué | Match exact fragile | `contains` robuste à l'encodage |
| Dimitri TOULON | Inclus dans les commerciaux | Exclu du périmètre commercial |
