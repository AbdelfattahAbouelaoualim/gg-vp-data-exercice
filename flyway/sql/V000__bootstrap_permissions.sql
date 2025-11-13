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

-- Grant CREATE SCHEMA privilege so Flyway can create new schemas if needed
GRANT CREATE SCHEMA ON DATABASE DWH_DEV_ABDELFATTAH TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- Grant privileges on existing schemas (created before CI/CD)
GRANT ALL PRIVILEGES ON SCHEMA staging TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;
GRANT ALL PRIVILEGES ON SCHEMA intermediate TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;
GRANT ALL PRIVILEGES ON SCHEMA marts TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- ===========================
-- PROD ENVIRONMENT BOOTSTRAP
-- ===========================

USE DATABASE DWH_PROD_ABDELFATTAH;

-- Create dedicated schema for Flyway metadata
CREATE SCHEMA IF NOT EXISTS FLYWAY_HISTORY
    COMMENT = 'Flyway schema history metadata';

-- Grant full ownership to the CI/CD role
GRANT OWNERSHIP ON SCHEMA FLYWAY_HISTORY TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- Grant CREATE SCHEMA privilege so Flyway can create new schemas if needed
GRANT CREATE SCHEMA ON DATABASE DWH_PROD_ABDELFATTAH TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- Create schemas (did not exist in PROD before CI/CD)
CREATE SCHEMA IF NOT EXISTS staging
    COMMENT = 'Staging layer - raw data ingestion';

CREATE SCHEMA IF NOT EXISTS intermediate
    COMMENT = 'Intermediate layer - business logic transformations';

CREATE SCHEMA IF NOT EXISTS marts
    COMMENT = 'Marts layer - final dimensional models';

-- Grant privileges on schemas
GRANT ALL PRIVILEGES ON SCHEMA staging TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;
GRANT ALL PRIVILEGES ON SCHEMA intermediate TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;
GRANT ALL PRIVILEGES ON SCHEMA marts TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify grants were applied
SHOW GRANTS TO ROLE ROLE_ABDELFATTAH_ABOUELAOUALIM;
