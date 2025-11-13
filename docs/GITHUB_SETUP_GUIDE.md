# Guide de Configuration GitHub - Architecture DataOps

**Projet:** gg-vp-data-exercice

**Date:** 2025-11-09

**Version:** 1.0

**Auteur:** Abdelfattah Abouelaoualim

---

## 📋 Table des Matières

1. [Audit Architecture DataOps](#audit-architecture-dataops)
2. [Configuration Branch Protection](#configuration-branch-protection)
3. [Configuration Environments](#configuration-environments)
4. [Configuration Secrets](#configuration-secrets)
5. [Workflow de Déploiement](#workflow-de-déploiement)
6. [Checklist de Vérification](#checklist-de-vérification)

---

## 🔍 Audit Architecture DataOps

### Principes Fondamentaux (extraits README.md)

L'architecture DataOps du projet repose sur **4 piliers** :

#### 1. **Isolation Environnements**

| Environnement | Database Snowflake | Branche Git | Accès Humain | Déploiement |
|---------------|-------------------|-------------|--------------|-------------|
| **DEV** | `DWH_DEV_ABDELFATTAH` | `develop` | DATA_ENGINEER (RW) | Auto (push sur develop) |
| **PROD** | `DWH_PROD_ABDELFATTAH` | `main` | DATA_ENGINEER (RO) | Manuel (approval requis) |

#### 2. **Stratégie Branches**

```
main (PROD)
  ↑ PR + Manual Approval
develop (DEV)
  ↑ PR + Auto-merge
feature/* (Feature Development)
  ↑ Development
```

**Règles** :
- ✅ `main` = **Production-ready code** → Require PR approval, all checks pass
- ✅ `develop` = **Integration branch** → Auto-deploy to DEV
- ✅ `feature/*` = **Feature development** → Delete after merge
- ✅ `hotfix/*` = **Production hotfixes** → Fast-track to main

#### 3. **Pipeline CI/CD (GitHub Actions)**

**Trigger Events** :
```yaml
on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]
  workflow_dispatch:  # Manual trigger
```

**Jobs Séquence** :

1. **lint** (sqlfluff) → Validation syntaxe SQL
2. **test-dev** → dbt deps + seed + run + test (DEV)
3. **deploy-dev** (si branch=develop) → Flyway + dbt run --full-refresh
4. **deploy-prod** (si branch=main) → **⚠️ MANUAL APPROVAL** → Flyway + dbt run + dbt test --fail-fast + git tag

#### 4. **Sécurité RBAC**

**Point Critique** : **Aucun humain n'a d'accès écriture direct en PROD**

- ✅ PROD : Seuls `DBT_RUNNER` et `FLYWAY_DEPLOYER` (service accounts via CI/CD)
- ✅ DEV : `DATA_ENGINEER` a full access
- ✅ Humains en PROD : READ-ONLY uniquement

---

## 🔒 Configuration Branch Protection

### Protection Branche `main` (PRODUCTION)

**Accès** : GitHub → Settings → Branches → Add branch protection rule

#### Configuration Exacte

```
Branch name pattern: main
```

**Règles à Activer** :

✅ **Require a pull request before merging**
   - ✅ Require approvals: **1**
   - ✅ Dismiss stale pull request approvals when new commits are pushed
   - ✅ Require review from Code Owners (optionnel, si fichier CODEOWNERS existe)

✅ **Require status checks to pass before merging**
   - ✅ Require branches to be up to date before merging
   - **Status checks requis** (à ajouter après premier run CI/CD) :
     - `lint` (sqlfluff validation)
     - `test-dev` (dbt tests on DEV)

✅ **Require conversation resolution before merging**
   - Force la résolution des commentaires de review

✅ **Require linear history**
   - Empêche merge commits (force rebase ou squash)

✅ **Do not allow bypassing the above settings**
   - **IMPORTANT** : Cocher pour admins aussi (sécurité maximale)
   - Exception : décocher uniquement pour "administrators" en cas d'urgence

✅ **Restrict who can push to matching branches**
   - Laisser **vide** = personne ne peut push directement
   - Tous les changements doivent passer par Pull Request

❌ **Allow force pushes** : **DÉSACTIVÉ** (jamais de force push sur main)

❌ **Allow deletions** : **DÉSACTIVÉ** (protection branche permanente)

---

### Protection Branche `develop` (DÉVELOPPEMENT)

**Accès** : GitHub → Settings → Branches → Add branch protection rule

#### Configuration Exacte

```
Branch name pattern: develop
```

**Règles à Activer** :

✅ **Require a pull request before merging**
   - Require approvals: **0** (auto-merge OK pour DEV)
   - ❌ Ne PAS cocher "Dismiss stale approvals" (DEV = plus permissif)

✅ **Require status checks to pass before merging**
   - ✅ Require branches to be up to date
   - **Status checks requis** :
     - `lint`
     - `test-dev`

✅ **Require conversation resolution before merging**

❌ **Require linear history** : DÉSACTIVÉ (DEV = flexible)

❌ **Do not allow bypassing** : DÉSACTIVÉ (DATA_ENGINEER peut bypass en DEV)

❌ **Restrict who can push** : VIDE (DATA_ENGINEER peut push direct si besoin)

✅ **Allow force pushes** : **ACTIVÉ** (uniquement pour develop, jamais pour main!)
   - Permet de nettoyer l'historique DEV si nécessaire

❌ **Allow deletions** : DÉSACTIVÉ

---

## 🌍 Configuration Environments

### Environment `production`

**Accès** : GitHub → Settings → Environments → New environment

#### Configuration Exacte

```
Environment name: production
```

**Protection Rules** :

✅ **Required reviewers**
   - **Reviewers** : `@AbdelfattahAbouelaoualim` (vous-même)
   - ⚠️ Ajouter aussi un collègue ou Product Owner si disponible
   - **Minimum** : 1 reviewer requis

✅ **Wait timer**
   - **0 minutes** (approval immédiat après demande)
   - ⚠️ Optionnel : 5-10 min si vous voulez un délai de réflexion

✅ **Deployment branches and tags**
   - **Selected branches only** : `main`
   - ⚠️ CRITIQUE : Seule la branche `main` peut déclencher un déploiement PROD

❌ **Deployment protection rules** : Laisser vide (GitHub Apps avancé)

---

## 🔐 Configuration Secrets

> **📝 Configuration Simplifiée (Exercice)**
>
> Dans cet exercice, nous utilisons **le même compte Snowflake** pour DEV et PROD (au lieu de créer des service accounts dédiés). Cela simplifie la configuration tout en maintenant la sécurité via l'approbation manuelle GitHub.
>
> **Configuration locale** : Les credentials Snowflake sont stockés dans `.envrc` (fichier ignoré par Git via `.gitignore`). Ce fichier contient les variables d'environnement (`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, etc.) chargées automatiquement par `direnv`.
>
> **Configuration GitHub Actions** : Les **7 mêmes credentials** sont dupliqués dans les GitHub Secrets pour permettre aux workflows CI/CD d'accéder à Snowflake.
>
> **Total : 7 secrets au lieu de 9**
>
> **⚠️ Production Réelle** : Créez des service accounts dédiés (`GITHUB_ACTIONS_BOT`) avec rôles spécifiques (`DBT_RUNNER`, `FLYWAY_DEPLOYER`). Voir README.md section "Implémentation RBAC".

### Secrets Repository (Actions)

**Accès** : GitHub → Settings → Secrets and variables → Actions → New repository secret

#### Secrets à Créer (7 au total)

**Secrets Communs (utilisés pour DEV et PROD)** :

```
SNOWFLAKE_ACCOUNT
  Value: [VOTRE_COMPTE_SNOWFLAKE]
  Exemple: qyxyvfy-be09150

SNOWFLAKE_USER
  Value: [VOTRE_USERNAME_SNOWFLAKE]
  Exemple: ABDELFATTAH_ABOUELAOUALIM

SNOWFLAKE_PASSWORD
  Value: [VOTRE_MOT_DE_PASSE_SNOWFLAKE]

SNOWFLAKE_ROLE
  Value: [VOTRE_RÔLE_SNOWFLAKE]
  Exemple: ROLE_ABDELFATTAH_ABOUELAOUALIM

SNOWFLAKE_WAREHOUSE
  Value: [VOTRE_WAREHOUSE_SNOWFLAKE]
  Exemple: COMPUTE_WH
```

**Secrets Spécifiques par Environnement** :

```
SNOWFLAKE_DATABASE_DEV
  Value: DWH_DEV_ABDELFATTAH

SNOWFLAKE_DATABASE_PROD
  Value: DWH_PROD_ABDELFATTAH
```

#### ⚠️ Notes Importantes

1. **Sécurité** : Bien que le même compte soit utilisé, la sécurité est assurée par :
   - Séparation stricte des databases (DEV vs PROD)
   - Approbation manuelle obligatoire pour PROD (GitHub Environment)
   - Audit trail complet via GitHub Actions logs

2. **Mots de passe** : Utiliser des mots de passe forts (12+ caractères minimum)
   - Ne jamais partager ou commiter les credentials

3. **Vérification des valeurs** : Utilisez les valeurs de votre configuration Snowflake locale
   - Ne copiez pas les exemples ci-dessus tels quels

---

## 🚀 Workflow de Déploiement

### Cas 1 : Feature Development → DEV

```bash
# 1. Créer feature branch depuis develop
git checkout develop
git pull origin develop
git checkout -b feature/my-new-feature

# 2. Développer + commit (Conventional Commits)
git add .
git commit -m "feat(marts): add new dimension dim_client"

# 3. Push vers GitHub
git push -u origin feature/my-new-feature

# 4. Créer Pull Request sur GitHub
# Base: develop ← Compare: feature/my-new-feature

# 5. CI/CD auto-exécute:
#    - lint (sqlfluff)
#    - test-dev (dbt deps + run + test)

# 6. Merger PR → develop
# → CI/CD auto-exécute deploy-dev:
#    - Flyway migrations (DEV)
#    - dbt run --target dev --full-refresh
#    - dbt test --target dev
```

**Résultat** : Code déployé automatiquement sur `DWH_DEV_ABDELFATTAH` ✅

---

### Cas 2 : DEV → PROD (Release)

```bash
# 1. Créer Pull Request sur GitHub
# Base: main ← Compare: develop

# 2. CI/CD auto-exécute:
#    - lint
#    - test-dev

# 3. ⚠️ CRITIQUE: Approval Manuelle Requise
# → Aller sur GitHub Actions
# → Cliquer "Review deployments"
# → Approuver le déploiement vers production

# 4. Après approval, CI/CD exécute deploy-prod:
#    - Flyway migrations (PROD)
#    - dbt run --target prod
#    - dbt test --target prod --fail-fast
#    - Create git tag (deploy-20251109-143052)

# 5. Merger PR → main
```

**Résultat** : Code déployé sur `DWH_PROD_ABDELFATTAH` après approval ✅

---

### Cas 3 : Hotfix Production

```bash
# 1. Créer hotfix branch depuis main
git checkout main
git pull origin main
git checkout -b hotfix/fix-scd2-bug

# 2. Fix rapide + commit
git add .
git commit -m "fix(marts): correct SCD2 is_current duplicate bug"

# 3. Push vers GitHub
git push -u origin hotfix/fix-scd2-bug

# 4. Créer PR: main ← hotfix/fix-scd2-bug
# 5. Approval + deploy PROD
# 6. Merger PR → main

# 7. IMPORTANT: Backport vers develop
git checkout develop
git pull origin main  # Merge main into develop
git push origin develop
```

---

## ✅ Checklist de Vérification

### Avant Premier Déploiement

- [ ] **Branch Protection `main`** configurée (require approval + status checks)
- [ ] **Branch Protection `develop`** configurée (status checks)
- [ ] **Environment `production`** créé (required reviewers + deployment branch `main`)
- [ ] **Secrets GitHub Actions** configurés (7 secrets - configuration simplifiée)
- [ ] **Flyway migrations** testées en DEV
- [ ] **dbt profiles.yml** configuré correctement
- [ ] **CI/CD workflow** `.github/workflows/ci_cd.yml` présent et valide

### Test du Workflow

1. **Test Lint** :
   ```bash
   sqlfluff lint models/ --dialect snowflake
   # Attendu: 0 errors
   ```

2. **Test dbt DEV** :
   ```bash
   dbt deps
   dbt seed --target dev
   dbt run --target dev
   dbt test --target dev
   # Attendu: All tests pass
   ```

3. **Test PR → develop** :
   - Créer une feature branch
   - Créer PR vers develop
   - Vérifier que CI/CD s'exécute (lint + test-dev)
   - Merger → vérifier deploy-dev s'exécute

4. **Test PR → main** :
   - Créer PR develop → main
   - Vérifier que approval est requis
   - Approuver
   - Vérifier que deploy-prod s'exécute
   - Vérifier que git tag est créé

---

## 🎯 Prochaines Étapes Recommandées

### Après Configuration GitHub

1. **Créer Pull Request** `feature/initial-setup` → `develop`
   - Description complète (voir README section "Workflow CI/CD")
   - Merger après validation CI/CD

2. **Créer Pull Request** `develop` → `main`
   - Release notes version 1.2.0
   - Approuver manuellement
   - Vérifier déploiement PROD

3. **Pull `main` en local** :
   ```bash
   git checkout main
   git pull origin main
   ```

4. **Nettoyer feature branch** :
   ```bash
   git branch -d feature/initial-setup
   git push origin --delete feature/initial-setup
   ```

### Améliorations Futures (Optionnel)

- [ ] Ajouter CODEOWNERS file (auto-assign reviewers)
- [ ] Configurer branch protection pour `hotfix/*` pattern
- [ ] Ajouter status check `security-scan` (Snyk, etc.)
- [ ] Configurer notifications Slack pour déploiements PROD
- [ ] Ajouter metrics GitHub Actions (temps build, success rate)

---

## 📚 Références

- [README.md - Section Workflow CI/CD](../README.md#workflow-cicd)
- [README.md - Section RBAC](../README.md#politique-de-gouvernance-et-sécurité-rbac)
- [GitHub Docs - Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub Docs - Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

**Dernière mise à jour** : 2025-11-09
**Maintenu par** : Data Engineering Team
