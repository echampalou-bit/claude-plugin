---
description: Installer la veille automatique (nouvelles immatriculations) sur un secteur, après le build supervisé
---
Lis la skill veille-secteur (skills/veille-secteur/SKILL.md) et installe la veille headless d'un secteur :

1. **Cadrage** — confirme la base cible + connecteur (get_project_url), le(s) département(s), les métiers/NAF à surveiller, et la fréquence (défaut : hebdomadaire lundi 7h).
2. **Déploie** l'edge function (references/veille-edge-function.md) via le connecteur cible, paramétrée sur le secteur.
3. **Pose le secret** GOOGLE_PLACES_KEY si l'enrichissement téléphone est voulu.
4. **Crée le cron** puis fais un **test à blanc** (curseur J-30) : vérifie le nombre d'insertions, l'absence de doublon, la cohérence left(cp,2)=département, et l'étape « Nouveau ».
5. **Propose** la routine d'enrichissement téléphone périodique (sur le modèle de enrichir-tel-nouveaux-prospects) sur la base du secteur.

N'active le cron qu'après un test à blanc concluant. La veille n'écrase jamais l'existant (insert on conflict do nothing).
