# 📚 Documentation - Globe VP Data

**Centre de Documentation Technique**

**Projet** : Dimension Magasin Unique et Historisée

**Stack** : dbt + Snowflake + Fuzzy Matching + GPS Validation

**Dernière mise à jour** : 2025-11-08

---

## 🎯 Objectif de cette Documentation

Cette documentation vous guide à travers **tous les aspects du projet**, des concepts de base aux décisions architecturales avancées. Que vous soyez débutant en dbt ou expert en data engineering, vous trouverez ici les ressources dont vous avez besoin.

---

## 📖 Table des Matières

### 🚀 Pour Démarrer

| Document | Description | Audience | Temps lecture |
|----------|-------------|----------|---------------|
| **[README Principal](../README.md)** | Vue d'ensemble complète du projet | Tous | 30 min |
| **[FAQ](FAQ.md)** | Questions fréquentes et solutions | Tous | Variable |

### 🏗️ Architecture & Décisions

| Document | Description | Date | Statut |
|----------|-------------|------|--------|
| **[ADR-001: SCD Type 2](ADR-001-scd-type-2.md)** | Pourquoi historiser avec SCD Type 2 ? | 2025-11-08 | ✅ Accepté |
| **[ADR-002: Matching Strategy](ADR-002-matching-strategy.md)** | Stratégie enrichissement géographique | 2025-11-08 | ✅ Accepté |
| **[ADR-003: Dédoublonnage Fuzzy](ADR-003-deduplication-fuzzy-matching.md)** | Algorithme fuzzy matching TH vs GI | 2025-11-08 | ✅ Accepté |
| **[ADR-004: Validation GPS](ADR-004-gps-validation-correction.md)** | Correction GPS via référentiel INSEE | 2025-11-08 | ✅ Implémenté |

### 📊 Données & Modèles (TODO)

| Document | Description |
|----------|-------------|
| **[Dictionnaire de Données](DATA_DICTIONARY.md)** | Tous les champs, définitions, types |
| **[Lineage Visuel](LINEAGE.md)** | Flux de données visualisé (avec dbt docs) |
| **[Sources de Données](SOURCES.md)** | TH.magasins, GI.magasins, communes INSEE |

### 🎓 Concepts & Pédagogie (TODO)

| Document | Description | Niveau |
|----------|-------------|--------|
| **[Qu'est-ce que le Fuzzy Matching ?](CONCEPTS_FUZZY_MATCHING.md)** | Explication vulgarisée + exemples | Débutant |
| **[Comprendre SCD Type 2](CONCEPTS_SCD2.md)** | Historisation expliquée simplement | Débutant |
| **[Distance GPS (Haversine)](CONCEPTS_HAVERSINE.md)** | Formule mathématique illustrée | Intermédiaire |
| **[Regex & Extraction de Texte](CONCEPTS_REGEX.md)** | Patterns regex pour extraction ville | Intermédiaire |

### 🛠️ Opérations & Maintenance (TODO)

| Document | Description |
|----------|-------------|
| **[Runbook Production](RUNBOOK.md)** | Gestion incidents & troubleshooting |
| **[Performance Tuning](PERFORMANCE.md)** | Optimiser les requêtes Snowflake |
| **[Gestion des Erreurs](TROUBLESHOOTING.md)** | Résolution problèmes courants |

### 📈 Roadmap & Changelog

| Document | Description |
|----------|-------------|
| **[ROADMAP](ROADMAP.md)** | Évolutions futures et planification |
| **[CHANGELOG](../CHANGELOG.md)** | Historique des changements par version |

---

## 🗺️ Parcours Recommandés

### 👤 "Je découvre le projet"

```mermaid
graph LR
A[README Principal] --> B[Concepts SCD2]
B --> C[Concepts Fuzzy Matching]
C --> D[FAQ]
```

**Temps estimé** : 1h30
**Documents** :
1. [README Principal](../README.md) - Vue d'ensemble
2. [Guide Débutant](GUIDE_DEBUTANT.md) - Installation + premier run
3. [Concepts SCD2](CONCEPTS_SCD2.md) - Comprendre l'historisation
4. [Concepts Fuzzy Matching](CONCEPTS_FUZZY_MATCHING.md) - Dédoublonnage
5. [FAQ](FAQ.md) - Questions courantes

---

### 💻 "Je veux développer une feature"

```mermaid
graph LR
    A[README Principal] --> B[Guide Macros]
    B --> C[ADR pertinent]
    C --> D[Data Dictionary]
    D --> E[Tests locaux]
```

**Temps estimé** : 2h
**Documents** :
1. [README Principal](../README.md) - Architecture
2. [Guide Macros](GUIDE_MACROS.md) - Réutiliser macros existantes
3. [ADRs](.) - Décisions architecturales
4. [Data Dictionary](DATA_DICTIONARY.md) - Schéma données
5. Tests : `dbt test --select +ma_feature`

---

### 🔍 "Je débogue un problème PROD"

```mermaid
graph LR
    A[Runbook] --> B[Troubleshooting]
    B --> C[Observabilité]
    C --> D[Logs Snowflake]
```

**Temps estimé** : 30 min
**Documents** :
1. [Runbook](RUNBOOK.md) - Procédures d'urgence
2. [Troubleshooting](TROUBLESHOOTING.md) - Erreurs courantes
3. [Guide Observabilité](GUIDE_OBSERVABILITY.md) - Métriques
4. Snowflake Query History

---

### 🎓 "Je veux comprendre les algorithmes"

```mermaid
graph LR
    A[ADR-003 Fuzzy] --> B[Guide Fuzzy Matching]
    B --> C[Concepts Haversine]
    C --> D[ADR-004 GPS]
    D --> E[Concepts Regex]
```

**Temps estimé** : 3h
**Documents** :
1. [ADR-003: Dédoublonnage](ADR-003-deduplication-fuzzy-matching.md)
2. [Guide Fuzzy Matching](GUIDE_FUZZY_MATCHING.md)
3. [Concepts Haversine](CONCEPTS_HAVERSINE.md)
4. [ADR-004: GPS Validation](ADR-004-gps-validation-correction.md)
5. [Concepts Regex](CONCEPTS_REGEX.md)

---

## 📊 Métriques Projet (État Actuel)

### Volumétrie

| Métrique | Valeur | Source |
|----------|--------|--------|
| **Sources TH** | 186,992 magasins | DTL_EXO.TH.magasins |
| **Sources GI** | 33,841 magasins | DTL_EXO.GI.magasins |
| **Total brut** | 220,833 magasins | UNION ALL |
| **Après GPS validation** | 65,280 magasins | int_magasins_geo_validated |
| **Après dédoublonnage** | 215,828 magasins | int_magasins_fuzzy_dedup |
| **Dimension finale** | 215,828 magasins | dim_magasin (SCD2) |
| **Golden records** | 2,684 (1.24%) | Doublons fusionnés |
| **Réduction totale** | -4,027 (-1.82%) | vs total brut |

### Qualité GPS (🚨 Découverte Majeure)

| Niveau Anomalie | Count | % | Action Appliquée |
|----------------|-------|---|------------------|
| **CRITIQUE** (>50 km) | 12,009 | 18.4% | ✅ Auto-corrigé (INSEE) |
| **MAJEURE** (10-50 km) | 7,848 | 12.0% | ✅ Auto-corrigé (INSEE) |
| **MINEURE** (1-10 km) | 32,944 | 50.5% | ⚠️ Flaggé (review manuel) |
| **OK** (≤1 km) | 12,479 | 19.1% | ✅ Coordonnées fiables |

**Résultat** : **80.9%** des magasins avaient des GPS suspects ! 30.4% corrigés automatiquement.

### Performance

| Modèle | Temps Build | Records | Statut |
|--------|-------------|---------|--------|
| stg_th_magasins | ~5s | 186,992 | ✅ |
| stg_gi_magasins | ~3s | 33,841 | ✅ |
| int_magasins_merged | ~10s | 220,833 | ✅ |
| int_magasins_geo_validated | **557s** (~9 min) | 65,280 | ✅ |
| int_magasins_fuzzy_dedup | **354s** (~6 min) | 216,806 | ✅ |
| int_magasins_augmented | ~15s | 216,806 | ✅ |
| dim_magasin | **833s** (~14 min) | 216,806 | ✅ |
| **Pipeline TOTAL** | **~20 minutes** | - | ✅ |

---

## 🏆 Points Forts du Projet

### ✨ Innovations Techniques

1. **Validation GPS via Référentiel Officiel**
   - Utilise données INSEE (source gouvernementale)
   - Extraction intelligente ville par regex
   - Correction adaptive par niveau d'anomalie
   - Traçabilité complète (coords originales préservées)

2. **Fuzzy Matching Optimisé**
   - Pré-filtrage par commune INSEE (réduction CROSS JOIN 99.97%)
   - Double critère : similarité nom (EDITDISTANCE) + distance GPS (Haversine)
   - Golden records : meilleur de chaque source
   - Seuils calibrés : 85% similarité, 500m distance

3. **Observabilité Intégrée**
   - Métriques qualité temps réel
   - Détection anomalies automatique
   - Tests dbt exhaustifs (30+ tests)
   - Documentation auto-générée (dbt docs)

4. **DataOps Complet**
   - CI/CD GitHub Actions
   - Déploiement multi-environnement (DEV/PROD)
   - RBAC Snowflake granulaire
   - Migrations DDL versionnées (Flyway)

---

## 📞 Support & Contact

### Obtenir de l'Aide

| Type de Question | Canal | Temps Réponse |
|------------------|-------|---------------|
| **Incident PROD** | PagerDuty → On-call engineer | Immédiat |
| **Question technique** | Slack #data-engineering | <2h (heures ouvrables) |
| **Demande feature** | Trello "Data Requests" | Review hebdo |
| **Bug documentation** | GitHub Issues | <48h |

### Contribuer à la Documentation

Cette documentation est un **document vivant** 📝. Vos contributions sont bienvenues !

**Comment contribuer** :
1. Fork le repo
2. Créer branche `docs/amelioration-xxx`
3. Éditer fichiers Markdown
4. Pull Request avec description claire
5. Review par équipe Data Engineering

**Standards documentation** :
- ✅ Langage clair et pédagogique
- ✅ Exemples concrets avec code
- ✅ Diagrammes Mermaid si applicable
- ✅ TOC (Table des Matières) si >500 lignes
- ✅ Date de mise à jour en en-tête

---

## 🗂️ Structure Complète du Répertoire

```
gg_vp_data/
├── README.md                          # 👈 Point d'entrée principal
├── CHANGELOG.md                       # Historique versions
├── .github/workflows/ci_cd.yml        # Pipeline CI/CD
├── dbt_project.yml                    # Config dbt
├── packages.yml                       # Dépendances (dbt_utils, etc.)
│
├── docs/                              # 📚 Documentation complète
│   ├── README.md                      # 👈 VOUS ÊTES ICI
│   ├── GUIDE_DEBUTANT.md             # Guide pas-à-pas
│   ├── GUIDE_MACROS.md               # Utilisation macros
│   ├── GUIDE_FUZZY_MATCHING.md       # Algorithme dédoublonnage
│   ├── GUIDE_GPS_VALIDATION.md       # Validation GPS
│   ├── GUIDE_OBSERVABILITY.md        # Métriques & monitoring
│   ├── DATA_DICTIONARY.md            # Dictionnaire données
│   ├── LINEAGE.md                    # Flux de données
│   ├── SOURCES.md                    # Sources TH/GI/INSEE
│   ├── CONCEPTS_*.md                 # Concepts pédagogiques
│   ├── RUNBOOK.md                    # Ops production
│   ├── TROUBLESHOOTING.md            # Debug problèmes
│   ├── FAQ.md                        # Questions fréquentes
│   ├── ROADMAP.md                    # Évolutions futures
│   │
│   └── ADR-00X-*.md                  # Architecture Decision Records
│       ├── ADR-001-scd-type-2.md
│       ├── ADR-002-matching-strategy.md
│       ├── ADR-003-deduplication-fuzzy-matching.md
│       └── ADR-004-gps-validation-correction.md
│
├── models/                            # Modèles dbt
│   ├── sources.yml                   # Déclaration sources
│   ├── staging/                      # Couche staging (nettoyage)
│   ├── intermediate/                 # Transformations métier
│   │   ├── int_magasins_merged.sql
│   │   ├── int_magasins_geo_validated.sql  # ⭐ GPS validation
│   │   ├── int_magasins_fuzzy_dedup.sql    # ⭐ Dédoublonnage
│   │   └── int_magasins_augmented.sql
│   ├── marts/                        # Tables finales (exposition)
│   │   └── dim_magasin.sql          # SCD Type 2
│   └── observability/                # Métriques qualité
│
├── macros/                            # Macros dbt réutilisables
│   ├── text_similarity.sql           # EDITDISTANCE normalisé
│   ├── haversine_distance.sql        # Distance GPS (km)
│   ├── extract_city_from_name.sql    # ⭐ Regex extraction ville
│   └── generate_schema_name.sql      # Override schéma
│
├── tests/                             # Tests custom dbt
│   ├── assert_scd2_one_current_per_store.sql
│   ├── assert_all_sources_in_dim.sql
│   └── assert_scd2_no_overlapping_dates.sql
│
├── analyses/                          # Analyses SQL ad-hoc
│   ├── dedup_metrics.sql             # Métriques dédoublonnage
│   ├── gps_correction_impact.sql     # Impact correction GPS
│   └── query_results.sql             # Résultats aggregés
│
├── seeds/                             # Données référentielles
│   └── communes-france-2025.csv      # Référentiel INSEE (2MB, 34k)
│
└── flyway/                            # Migrations DDL
    ├── flyway.conf
    └── sql/
        ├── V001__create_databases_schemas.sql
        ├── V002__create_warehouses.sql
        ├── V003__create_roles.sql
        └── V004__grant_permissions.sql
```

---

## 🎯 Prochaines Étapes Suggérées

Selon votre rôle et objectif :

### 👨‍💻 Je suis Développeur
→ Lire [README Principal](../README.md)
→ Setup environnement local
→ Exécuter `dbt run` et `dbt test`
→ Contribuer première feature

### 📊 Je suis Data Analyst
→ Lire [README Principal](../README.md)
→ Explorer [Dictionnaire de Données](DATA_DICTIONARY.md)
→ Requêter `dim_magasin` dans Snowflake
→ Créer dashboard BI

### 🏗️ Je suis Architecte Data
→ Lire tous les [ADRs](.)
→ Analyser [Lineage](LINEAGE.md)
→ Review [Performance Tuning](PERFORMANCE.md)
→ Proposer évolutions ([ROADMAP](ROADMAP.md))

### 👔 Je suis Product Owner
→ Lire [README Principal](../README.md)
→ Comprendre [Concepts SCD2](CONCEPTS_SCD2.md)
→ Explorer dashboard Observabilité
→ Prioriser backlog via [ROADMAP](ROADMAP.md)

---

## 📜 Licence & Copyright

**Propriété** : Globe Data Engineering Team

**Confidentialité** : Internal Use Only

**Dernière révision** : 2025-11-09

Pour toute question légale ou de propriété intellectuelle, contacter : legal@globe.com

---

**Document vivant** 📝 - Contribuez pour l'améliorer !

_Cette documentation évolue avec le projet. Si vous trouvez une erreur, une imprécision, ou avez une suggestion, ouvrez un GitHub Issue ou contactez #data-engineering sur Slack._
