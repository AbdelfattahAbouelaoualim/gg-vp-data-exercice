-- =====================================================
-- Flyway Migration V000: Bootstrap Permissions
-- Description: Initial permissions required for Flyway to operate
-- Author: Data Engineering Team
-- Date: 2025-11-12
-- =====================================================

-- IMPORTANT: This migration must be run MANUALLY by an ACCOUNTADMIN
-- before Flyway can execute any automated migrations.
--
-- WHY: Flyway needs these permissions to create its metadata schema
-- and manage other schemas in the database.

-- ==========================
-- DEV ENVIRONMENT BOOTSTRAP
-- ==========================

USE DATABASE DWH_DEV_ABDELFATTAH;

-- Create dedicated schema for Flyway metadata
CREATE SCHEMA IF NOT EXISTS FLYWAY_HISTORY
    COMMENT = 'Flyway schema history metadata';

-- Grant full ownership to the CI/CD role
GRANT OWNERSHIP ON SCHEMA FLYWAY_HISTORY TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- Grant CREATE SCHEMA privilege so Flyway can create staging/intermediate/marts
GRANT CREATE SCHEMA ON DATABASE DWH_DEV_ABDELFATTAH TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- ===========================
-- PROD ENVIRONMENT BOOTSTRAP
-- ===========================

USE DATABASE DWH_PROD_ABDELFATTAH;

-- Create dedicated schema for Flyway metadata
CREATE SCHEMA IF NOT EXISTS FLYWAY_HISTORY
    COMMENT = 'Flyway schema history metadata';

-- Grant full ownership to the CI/CD role
GRANT OWNERSHIP ON SCHEMA FLYWAY_HISTORY TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- Grant CREATE SCHEMA privilege so Flyway can create staging/intermediate/marts
GRANT CREATE SCHEMA ON DATABASE DWH_PROD_ABDELFATTAH TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify grants were applied
SHOW GRANTS TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;
