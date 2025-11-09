-- =====================================================
-- Flyway Migration V001: Create Databases and Schemas
-- Description: Initialize database and schema structure for DWH
-- Author: Data Engineering Team
-- Date: 2025-11-08
-- =====================================================

-- Create databases if they don't exist
-- Note: This should be run with SYSADMIN or ACCOUNTADMIN role

-- Development database
CREATE DATABASE IF NOT EXISTS DWH_DEV_ABDELFATTAH
    COMMENT = 'Development data warehouse for gg_vp_data project';

-- Production database
CREATE DATABASE IF NOT EXISTS DWH_PROD_ABDELFATTAH
    COMMENT = 'Production data warehouse for gg_vp_data project';

-- =====================================================
-- DEV Schemas
-- =====================================================

USE DATABASE DWH_DEV_ABDELFATTAH;

CREATE SCHEMA IF NOT EXISTS staging
    COMMENT = 'Staging layer: normalized source data with quality flags';

CREATE SCHEMA IF NOT EXISTS intermediate
    COMMENT = 'Intermediate layer: business logic transformations';

CREATE SCHEMA IF NOT EXISTS marts
    COMMENT = 'Marts layer: production-ready dimensions and facts';

CREATE SCHEMA IF NOT EXISTS observability
    COMMENT = 'Observability layer: data quality and monitoring views';

-- =====================================================
-- PROD Schemas
-- =====================================================

USE DATABASE DWH_PROD_ABDELFATTAH;

CREATE SCHEMA IF NOT EXISTS staging
    COMMENT = 'Staging layer: normalized source data with quality flags';

CREATE SCHEMA IF NOT EXISTS intermediate
    COMMENT = 'Intermediate layer: business logic transformations';

CREATE SCHEMA IF NOT EXISTS marts
    COMMENT = 'Marts layer: production-ready dimensions and facts';

CREATE SCHEMA IF NOT EXISTS observability
    COMMENT = 'Observability layer: data quality and monitoring views';

-- =====================================================
-- Source database (DTL_EXO) - Read-only
-- =====================================================

-- Note: DTL_EXO is assumed to exist and be managed externally
-- This script only grants read permissions (see V004)

-- =====================================================
-- Verification
-- =====================================================

-- Show created databases
SHOW DATABASES LIKE '%ABDELFATTAH';

-- Show created schemas in DEV
USE DATABASE DWH_DEV_ABDELFATTAH;
SHOW SCHEMAS;

-- Show created schemas in PROD
USE DATABASE DWH_PROD_ABDELFATTAH;
SHOW SCHEMAS;
