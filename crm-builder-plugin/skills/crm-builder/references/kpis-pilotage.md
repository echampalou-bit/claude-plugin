# KPIs et pilotage commercial

Patterns pour dashboards, objectifs, scoring et alertes. Règle de base : un dashboard n'a de valeur que si chaque chiffre déclenche une décision possible.

## KPIs commerciaux standards

### Funnel (par période, par commercial, par agence)
`nouveaux contacts → RDV → dossiers déposés → signés` + taux de transformation à chaque étape.

### Production
- CA / volume financé, nombre de dossiers signés, panier moyen
- CA par source : apporteurs / leads société / recommandations perso — classification par règle explicite (présence d'un `prescriber_id`, valeur du champ `source`)
- Taux de transformation global, durée moyenne de cycle

### Activité
- Relances en retard (reminders dépassés), prospects sans interaction depuis X jours
- Interactions par semaine par commercial

### Objectifs
- Réalisé vs objectif par métrique et par période (table `targets`), timeline de progression
- Templates d'objectifs par séniorité (junior/confirmé/expert) pour ne pas ressaisir

## Pattern kpi_snapshots (pré-calcul)

Ne pas calculer les KPIs à la volée sur chaque affichage quand la source est une API externe ou des agrégations lourdes :
- Un cron périodique calcule les métriques par (user, agency, period) et écrit dans `kpi_snapshots.payload` (jsonb)
- Le dashboard lit les snapshots = affichage instantané + historique gratuit
- Bouton "recalculer" admin pour forcer un refresh

Les calculs vivent dans des fonctions pures dédiées (`computeFunnelKpis`, `computeSourcesKpis`…) testables indépendamment de l'UI.

## Health Score (scoring d'un portefeuille)

Pour prioriser un portefeuille (apporteurs, partenaires) :
- **Matrice 2D** : volume (aucun/faible/moyen/élevé) × transformation (faible/moyen/fort) → tier
- Tiers ordonnés : `dormant → actif → bronze → argent → or → diamant`
- Seuils configurables en base (`score_config`) — jamais en dur dans le code : le métier doit pouvoir les ajuster sans déploiement
- Historiser les changements de tier (`tier_history`) : les mouvements (un "or" qui descend) sont plus actionnables que les niveaux

## Système d'alertes

- `alert_rules` configurables (admin) : condition (métrique + seuil + fenêtre) → cible (rôle/user)
- Cron quotidien évalue les règles → crée des `alerts` (statuts : non-lu / snoozé / résolu)
- Exemples utiles : "partenaire or sans apport depuis 45j", "courtier sous 50% d'objectif à mi-mois", "prospect chaud sans interaction depuis 7j"
- Une alerte sans action associée est du bruit : chaque règle définit l'action attendue dans son libellé

## Dashboard

- Widgets par rôle : un courtier voit SES relances/objectifs/top apporteurs ; un directeur voit son agence ; l'admin voit le réseau
- Configurable par utilisateur (`dashboard_config` jsonb) plutôt qu'un dashboard figé par rôle
- 4-6 widgets max visibles — au-delà, rien n'est lu
- Sélecteurs période (mois/trimestre/année) et agence partagés entre modules (composants communs `PeriodSelector`, `AgencySelector`)
