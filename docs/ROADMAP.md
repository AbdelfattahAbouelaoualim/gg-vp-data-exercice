# ROADMAP DATA - Projet Magasins Unifiés

**Date:** 2025-11-08

**Version:** 1.0

**Statut:** En production (MVP)

---

## Table des matières

1. [Vision et Objectifs](#vision-et-objectifs)
2. [Cadre de Priorisation](#cadre-de-priorisation)
3. [Roadmap Phases](#roadmap-phases)
4. [Backlog Fonctionnel](#backlog-fonctionnel)
5. [Critères d'Arbitrage](#critères-darbitrage)
6. [Dépendances et Risques](#dépendances-et-risques)

---

## Vision et Objectifs

### Vision

> **"Fournir une source de vérité unique et historisée des magasins TH et GI, accessible en self-service avec garanties de qualité, pour supporter l'expansion commerciale et l'analytics avancée."**

### Objectifs Stratégiques (exemple)

| Objectif | Indicateur | Cible Q2 2026 |
|----------|-----------|---------------|
| **Qualité** | Taux de complétude enrichissement | ≥ 95% |
| **Performance** | Latence rafraîchissement | < 1h |
| **Adoption** | Nombre de dashboards consommateurs | ≥ 10 |
| **Gouvernance** | Couverture tests automatisés | 100% |
| **Coût** | Coût Snowflake / magasin / mois | < 0.01€ |

---

## Cadre de Priorisation

### Scoring Framework (RICE)

Chaque initiative est scorée selon 4 dimensions :

```
Score RICE = (Reach × Impact × Confidence) / Effort

- Reach (R):      Nombre d'utilisateurs/systèmes impactés (0-1000)
- Impact (I):     Valeur métier (1=Minimal, 3=Modéré, 5=Élevé, 10=Massif)
- Confidence (C): Certitude estimation (50%, 80%, 100%)
- Effort (E):     Jours-personne (0.5 - 20)
```

### Matrice d'Impact

| Dimension | Poids | Exemples |
|-----------|-------|----------|
| **Revenus** | 40% | Amélioration ciblage → +5% CA |
| **Coûts** | 25% | Réduction requêtes manuelles → -2h/semaine |
| **Risque** | 20% | Conformité RGPD, incident data |
| **Expérience** | 15% | Réduction délai accès donnée |

### Catégories de Priorisation

1. **P0 - Critique** : Bloquant production, conformité légale
2. **P1 - Haute** : Impact métier majeur, court terme
3. **P2 - Moyenne** : Amélioration incrémentale, moyen terme
4. **P3 - Basse** : Nice-to-have, long terme

---

## Roadmap Phases (exemple)

### ✅ Phase 0 : MVP (Complétée - Nov 2025)

**Objectif** : Dimension magasin historisée opérationnelle avec CI/CD

| Livrable | Statut | Date |
|----------|--------|------|
| SCD Type 2 `dim_magasin` | ✅ Complété | 2025-11-06 |
| Enrichissement communes France 2025 | ✅ Complété | 2025-11-07 |
| Fuzzy matching EDITDISTANCE + Haversine | ✅ Complété | 2025-11-07 |
| CI/CD GitHub Actions (4 jobs) | ✅ Complété | 2025-11-08 |
| Flyway migrations RBAC | ✅ Complété | 2025-11-08 |
| Tests dbt (generic + custom + expectations) | ✅ Complété | 2025-11-08 |
| Documentation (README, ADRs) | ✅ Complété | 2025-11-08 |

**Métriques MVP** :
- 219 000 magasins unifiés (TH + GI)
- 95%+ enrichissement géographique
- 0 déploiement manuel production
- 100% tests passés

---

### 🚧 Phase 1 : Industrialisation (Q1 2026)

**Objectif** : Production-ready avec monitoring avancé et optimisations

| Initiative | Priorité | Score RICE | Effort | Début |
|-----------|----------|------------|--------|-------|
| **Alerting temps réel** (Slack/PagerDuty) | P1 | 96 | 3j | Janv 2026 |
| **Dashboard Observabilité** (Grafana) | P1 | 80 | 4j | Janv 2026 |
| **Optimisation performance** (clustering, partitioning) | P1 | 75 | 5j | Fév 2026 |
| **Snapshots dbt** pour audits historiques | P2 | 60 | 3j | Fév 2026 |
| **Tests E2E** (validation bout-en-bout) | P1 | 72 | 4j | Mars 2026 |
| **Documentation utilisateurs** (guides self-service) | P2 | 55 | 2j | Mars 2026 |

**Livrables Phase 1** :
- ✅ Alerte < 5min en cas d'échec pipeline
- ✅ Dashboard temps réel qualité données
- ✅ Réduction 50% coût requêtes (clustering)
- ✅ 100% couverture tests E2E

**Calcul RICE Exemple - Alerting** :
```
Reach:      50 utilisateurs data team
Impact:     10 (évite incidents majeurs)
Confidence: 100% (technologie mature)
Effort:     3 jours

Score = (50 × 10 × 1.0) / 3 = 166.7 → Top priorité
```

---

### 🔮 Phase 2 : Enrichissement Avancé (Q2 2026)

**Objectif** : Données augmentées pour analytics prédictive

| Initiative | Priorité | Score RICE | Effort | Début |
|-----------|----------|------------|--------|-------|
| **Données démographiques INSEE** (pop, revenus) | P1 | 85 | 6j | Avril 2026 |
| **Analyse concurrence** (densité magasins concurrents) | P2 | 70 | 8j | Mai 2026 |
| **Scoring potentiel** (ML prédiction CA magasin) | P1 | 90 | 10j | Mai 2026 |
| **Zones de chalandise** (isochrones 15/30/60min) | P2 | 65 | 7j | Juin 2026 |
| **API Reverse Geocoding** (amélioration localisation) | P3 | 40 | 5j | Backlog |

**Livrables Phase 2** :
- ✅ 20+ attributs démographiques par magasin
- ✅ Score potentiel 0-100 avec confiance
- ✅ Carte chaleur densité concurrence
- ✅ Adoption par équipe Expansion Commerciale

**Use Case Métier** :
```
Question Métier: "Où ouvrir le prochain magasin GI ?"

Réponse Data-Driven:
1. Filtrer communes score potentiel > 80
2. Exclure zones avec concurrent < 5km
3. Prioriser pop > 50k habitants
4. Vérifier historique fermetures (SCD Type 2)

→ Top 10 emplacements optimaux avec ROI estimé
```

---

### 🌟 Phase 3 : Écosystème Data (Q3-Q4 2026)

**Objectif** : Plateforme self-service multi-entités

| Initiative | Priorité | Score RICE | Effort | Début |
|-----------|----------|------------|--------|-------|
| **Dimension Produits** (catalogue unifié TH+GI) | P1 | 88 | 15j | Juil 2026 |
| **Dimension Employés** (RH analytics) | P2 | 60 | 12j | Sept 2026 |
| **Fact Ventes** (grain transaction) | P0 | 120 | 20j | Août 2026 |
| **Data Catalog** (Atlan, Metaphor) | P2 | 55 | 8j | Oct 2026 |
| **Lineage automatique** (dbt + Great Expectations) | P2 | 50 | 6j | Nov 2026 |
| **Semantic Layer** (dbt Metrics, Cube.js) | P1 | 75 | 10j | Déc 2026 |

**Livrables Phase 3** :
- ✅ 5 dimensions + 2 tables de faits opérationnelles
- ✅ Self-service analytics (Looker, Tableau)
- ✅ Temps moyen création dashboard : < 2h
- ✅ 80% réduction tickets data ad-hoc

---

## Backlog Fonctionnel

### P0 - Critique (À traiter immédiatement)

| ID | Titre | Description | Bloquant | Effort |
|----|-------|-------------|----------|--------|
| P0-001 | **Gestion secrets GitHub Actions** | Stocker credentials Snowflake dans GitHub Secrets | Déploiement PROD | 0.5j |
| P0-002 | **Configuration environnements CI/CD** | Créer environnement `production` avec reviewers | Workflow complet | 0.5j |
| P0-003 | **Baseline Git** | Initial commit avec structure actuelle | Versionning | 0.5j |

### P1 - Haute Priorité (Q1 2026)

| ID | Titre | Description | Impact Métier | Effort |
|----|-------|-------------|---------------|--------|
| P1-001 | **Alerting échecs pipeline** | Slack notification si `dbt test` échoue | Réduction MTTR | 3j |
| P1-002 | **Dashboard Observabilité** | Grafana : freshness, volumétrie, qualité | Visibilité opérationnelle | 4j |
| P1-003 | **Clustering dim_magasin** | Partitionnement par `source_system`, `is_current` | -40% coût requêtes | 2j |
| P1-004 | **Snapshots dbt** | Historisation auditable états dimension | Compliance | 3j |
| P1-005 | **Tests E2E** | Validation complète DEV → PROD | Confiance déploiements | 4j |
| P1-006 | **Données démographiques INSEE** | Enrichissement pop, revenus médians | Analytics expansion | 6j |

### P2 - Moyenne Priorité (Q2 2026)

| ID | Titre | Description | Bénéfice | Effort |
|----|-------|-------------|----------|--------|
| P2-001 | **Analyse concurrence** | Distance au concurrent le + proche | Insights stratégiques | 8j |
| P2-002 | **Zones de chalandise** | Calcul isochrones 15/30/60min | Marketing territorial | 7j |
| P2-003 | **Documentation utilisateurs** | Guides self-service + FAQ | Adoption plateforme | 2j |
| P2-004 | **Data Catalog** | Métadonnées searchables (Atlan) | Découvrabilité | 8j |
| P2-005 | **Optimisation seed communes** | Incremental load au lieu de full-refresh | -90% temps chargement | 3j |

### P3 - Basse Priorité (Backlog)

| ID | Titre | Description | Effort |
|----|-------|-------------|--------|
| P3-001 | **API Reverse Geocoding** | Alternative EDITDISTANCE pour edge cases | 5j |
| P3-002 | **Machine Learning matching** | Modèle custom pour fuzzy matching | 15j |
| P3-003 | **Données météo** | Enrichissement climat par localisation | 6j |
| P3-004 | **Mobile app admin** | Validation manuelle matchings douteux | 12j |

---

## Critères d'Arbitrage

### Règles de Décision

#### 1. Trade-off Vitesse vs. Qualité

| Scénario | Décision | Justification |
|----------|----------|---------------|
| MVP vs. Production-ready | MVP d'abord | Valider use case avant investissement lourd |
| Fuzzy matching approx. vs. ML | Approx. (EDITDISTANCE) | 95% précision suffit, évite dépendance ML |
| Tests manuels vs. CI/CD | CI/CD obligatoire | Non-négociable (exigence exercice) |

#### 2. Build vs. Buy

| Besoin | Décision | Alternative Évaluée |
|--------|----------|---------------------|
| Fuzzy matching | **Build** (macros dbt) | API Google Maps (coût $1,100+) |
| Observabilité | **Build** (modèles dbt) | Monte Carlo Data (SaaS $2,500/mois) |
| Data Catalog | **Buy** (Atlan) | Build custom (20j effort) |
| Semantic Layer | **Buy** (dbt Metrics) | Build (15j effort) |

**Seuil** : Si effort build > 10j ET solution SaaS < $500/mois → Buy

#### 3. Priorisation en Cas de Conflit

**Ordre de priorité** :
1. **Conformité/Sécurité** (RGPD, RBAC)
2. **Stabilité Production** (tests, alerting)
3. **Impact Revenus** (analytics expansion commerciale)
4. **Efficacité Opérationnelle** (self-service)
5. **Innovation Technique** (ML, features avancées)

**Exemple** :
```
Conflit: Alerting (P1) vs. Scoring ML (P1)

Décision: Alerting d'abord
Raison:  Stabilité Production > Innovation
```

---

## Dépendances et Risques

### Dépendances Critiques

| Dépendance | Type | Impact si Bloquée | Mitigation |
|------------|------|-------------------|------------|
| **Snowflake Prod** | Infrastructure | 🔴 Bloquant total | Accord SLA avec IT (99.9% uptime) |
| **GitHub Actions** | CI/CD | 🟠 Déploiements manuels | Fallback scripts Bash locaux |
| **Seed communes INSEE** | Données | 🟡 Enrichissement dégradé | Cache local + fallback API |
| **Flyway** | Migrations | 🟠 Rollback manuel | Documentation procédures d'urgence |

### Risques Projet

| Risque | Probabilité | Impact | Score | Mitigation |
|--------|-------------|--------|-------|------------|
| **Dérive qualité données sources** | Moyenne | Élevé | 🟠 12 | Freshness tests + alerting |
| **Explosion coûts Snowflake** | Faible | Élevé | 🟡 9 | Clustering + monitoring quotas |
| **Turnover équipe data** | Moyenne | Moyen | 🟡 9 | Documentation exhaustive + ADRs |
| **Changement schéma source TH/GI** | Faible | Critique | 🟠 12 | Contract tests + versioning API |
| **Indisponibilité GitHub** | Très faible | Moyen | 🟢 4 | Fallback scripts locaux |

**Légende Score** : Probabilité (1-5) × Impact (1-5)
- 🔴 15-25 : Critique
- 🟠 10-14 : Élevé
- 🟡 5-9 : Modéré
- 🟢 1-4 : Faible

### Plan de Contingence

#### Scénario 1 : Panne Snowflake Prod

```
1. [T+0min]  Alerte automatique Slack
2. [T+5min]  Vérification status.snowflake.com
3. [T+10min] Basculement lecture sur DEV (mode dégradé)
4. [T+30min] Communication stakeholders
5. [Post]    Post-mortem + amélioration monitoring
```

#### Scénario 2 : Test CI/CD Échoue en PROD

```
1. [T+0min]  Pipeline bloqué (aucun déploiement)
2. [T+5min]  Notification équipe + incident Jira
3. [T+15min] Analyse logs + identification root cause
4. [T+1h]    Fix + re-run tests en DEV
5. [T+2h]    Nouvelle tentative déploiement PROD
6. [Échec]   Rollback automatique via Flyway
```

---

## Métriques de Succès Roadmap

### KPIs Trimestriels

| Métrique | Q1 2026 | Q2 2026 | Q3 2026 | Q4 2026 |
|----------|---------|---------|---------|---------|
| **Couverture tests** | 100% | 100% | 100% | 100% |
| **MTTR incidents** | < 1h | < 30min | < 15min | < 10min |
| **Coût Snowflake** | Baseline | -20% | -35% | -50% |
| **Dashboards actifs** | 3 | 8 | 15 | 25 |
| **Utilisateurs quotidiens** | 5 | 15 | 30 | 50 |
| **Enrichissement** | 95% | 98% | 99% | 99.5% |

### OKRs 2026

**Objectif 1** : Plateforme data fiable et performante
- **KR1** : 99.9% uptime pipeline production
- **KR2** : Latence rafraîchissement < 30min (vs. 1h actuel)
- **KR3** : 0 incident majeur non-détecté par monitoring

**Objectif 2** : Adoption self-service généralisée
- **KR1** : 80% requêtes analytics via dashboards (vs. SQL ad-hoc)
- **KR2** : Temps moyen création dashboard < 2h
- **KR3** : NPS utilisateurs ≥ 8/10

**Objectif 3** : Impact métier mesurable
- **KR1** : 3 décisions expansion commerciale basées sur scoring ML
- **KR2** : Réduction 50% temps analyse potentiel nouveaux sites
- **KR3** : ROI projet ≥ 300% (gains vs. coûts)

---

## Processus de Révision

### Cadence de Mise à Jour

| Fréquence | Format | Participants |
|-----------|--------|--------------|
| **Hebdomadaire** | Stand-up (15min) | Data Engineers |
| **Bimensuel** | Sprint Review | + Product Owner |
| **Mensuel** | Roadmap Update | + Stakeholders Métier |
| **Trimestriel** | Strategic Review | + Direction |

### Critères d'Ajustement Roadmap

**Ajout initiative** :
- Score RICE > 60 OU Priorité P0
- Alignement OKRs 2026
- Ressources disponibles (< 80% capacité team)

**Retrait initiative** :
- Score RICE < 30 sur 2 trimestres consécutifs
- Dépendance bloquée sans résolution
- Pivot stratégique métier

**Répriorisation** :
- Incident production → P0 immédiat
- Opportunité revenus > €500k → P1
- Feedback utilisateurs critique → +1 priorité

---

## Contacts et Ownership

| Rôle | Responsable | Scope |
|------|-------------|-------|
| **Product Owner** | [---] | Priorisation roadmap, arbitrages métier |
| **Tech Lead** | [---] | Architecture, ADRs, reviews techniques |
| **Data Engineer** | [---] | Développement pipelines, tests |
| **Analytics Engineer** | [---] | Modèles dbt, documentation |

---

## Annexes

### A. Template Proposition Nouvelle Initiative

```markdown
# [ID] Titre Initiative

## Contexte
[Pourquoi maintenant ?]

## Objectif
[Résultat attendu mesurable]

## Scoring RICE
- Reach: [0-1000]
- Impact: [1/3/5/10]
- Confidence: [50%/80%/100%]
- Effort: [jours-personne]
- **Score**: [calcul]

## Dépendances
- [Liste]

## Risques
- [Liste + mitigations]

## Alternatives Considérées
- [Option 1] : [Pourquoi rejetée]
- [Option 2] : [...]

## Décision
[Approuvée/Rejetée/En attente]
```

### B. Changelog Roadmap

| Date | Changement | Auteur |
|------|------------|--------|
| 2025-11-08 | Création ROADMAP v1.0 | Abdelfattah Abouelaoualim |
| 2026-01-15 | Ajout P1-007 : API Gateway *(planifié)* | - |
| 2026-04-01 | Répriorisation Phase 3 → Q4 *(planifié)* | - |

---

**Document vivant** – Dernière mise à jour : 2025-11-08

**Prochaine révision** : 2026-01-15
