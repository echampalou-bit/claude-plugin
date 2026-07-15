# Plugin `ouverture-agence`

Boîte à outils clef-en-main pour **ouvrir une agence sur un nouveau secteur**. Construit une base de
prospection B2B locale exhaustive et enrichie, la qualifie sans faux positifs, l'importe dans le CRM
cible, puis installe une veille automatique des nouvelles immatriculations.

Pensé pour être lancé **~2-3 semaines avant l'ouverture** d'un secteur (ex. départements 58 + 18,
point de vente à Nevers). Réutilisable pour toute future ouverture.

## Contenu

| Type | Nom | Rôle |
|---|---|---|
| Skill | `prospection-secteur` | Build supervisé : socle officiel → Google Maps → géocodage BAN → qualification auditée → import. Multi-métiers × multi-départements en une passe. Base cible **paramétrable**. |
| Skill | `veille-secteur` | Veille headless : edge function + cron qui pousse les nouvelles immatriculations à l'étape « Nouveau ». |
| Commande | `/ouverture-secteur` | Déclencheur du build supervisé (pose le cadrage puis déroule tout). |
| Commande | `/veille-secteur` | Installe la veille après le build. |

## Métiers cibles
Agences immobilières **physiques**, **mandataires** de réseau (Capifrance, IAD, SAFTI, Optimhome…),
**études notariales**, **constructeurs de maisons individuelles**.

> Nuance clé vs `prospection-locale` : ici les **mandataires sont une cible** (gardés), pas une
> exclusion.

## Base cible (swappable)
Par défaut = **Mini pulse** (`supabase-minipulse`, projet `gqluidscpcvrivxzfbpm`). Pour viser une
autre base, ne modifier que le bloc « Connecteur cible » en tête de la skill `prospection-secteur`.

## Installation
Plugin local (git). Ajouter ce dossier comme marketplace puis installer le plugin `ouverture-agence`.
Le `marketplace.json` et le `plugin.json` sont dans `.claude-plugin/`.

## Points de vigilance
- Google Maps riche = **supervisé** (Claude in Chrome). La veille = **headless** (API Places).
- L'import réel dans Mini pulse nécessite le connecteur `supabase-minipulse` actif dans la session ;
  sinon, livraison en CSV/SQL à exécuter côté bon projet.
- Constructeurs MI : socle SIRENE bruité → plus de `a_verifier` à trier (prévu par la RÈGLE D'OR).

Auteur : Edgar Champalou.
