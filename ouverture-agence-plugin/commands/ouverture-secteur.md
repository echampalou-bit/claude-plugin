---
description: Lancer la prospection clef-en-main d'un nouveau secteur (agences, mandataires, notaires, constructeurs) avant l'ouverture d'une agence
---
Lis la skill prospection-secteur (skills/prospection-secteur/SKILL.md) et lance un run d'ouverture de secteur en suivant sa méthode :

1. **Cadrage (Étape 0)** — pose (une par une si l'utilisateur n'a pas déjà répondu) : les départements du secteur + la ville pivot ; les métiers cibles parmi agences_physiques / mandataires / notaires / constructeurs_mi (défaut : les 4) ; la base cible (défaut Mini pulse) ; le mode de livraison (import direct vs CSV/SQL).
2. **Renseigne le bloc « Connecteur cible »** et VÉRIFIE la destination avec get_project_url avant tout write.
3. **Crée une todo-list** (1 entrée par métier × département) et déroule le pipeline 6 étapes pour chacun, en persistant au fil de l'eau.
4. **Applique la RÈGLE D'OR** (audit avant tout import/suppression) et fais confirmer par l'utilisateur avant d'écrire dans la base.
5. **Dédoublonne** entre métiers, **importe** avec le tag secteur, puis **livre un rapport de run** (par métier × département : socle, enrichi, géocodé, importé, a_verifier).
6. **Propose d'installer la veille** (commande /veille-secteur) pour prendre le relais en continu.

Ne supprime jamais et n'écrase jamais une fiche travaillée sans confirmation. En cas de doute sur une donnée, marque a_verifier plutôt que d'inventer.
