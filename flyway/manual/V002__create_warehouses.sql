-- =====================================================
-- Flyway Migration V002: Create Warehouses
-- Description: Create dedicated warehouses for different workloads
-- Author: Data Engineering Team
-- Date: 2025-11-08
-- =====================================================

-- Note: This should be run with SYSADMIN or ACCOUNTADMIN role

-- =====================================================
-- TRANSFORM_WH: For dbt transformations and ETL
-- =====================================================

CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH
    WITH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 60              -- Suspend after 1 minute of inactivity
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for dbt transformations and ETL workloads';

-- =====================================================
-- ANALYTICS_WH: For analysts and reporting queries
-- =====================================================

CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 120             -- Suspend after 2 minutes of inactivity
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for data analysts and reporting queries';

-- =====================================================
-- CLIENT_WH: For external client access (read-only)
-- =====================================================

CREATE WAREHOUSE IF NOT EXISTS CLIENT_WH
    WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 180             -- Suspend after 3 minutes of inactivity
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for external client read-only access';

-- =====================================================
-- ADMIN_WH: For administrative tasks
-- =====================================================

CREATE WAREHOUSE IF NOT EXISTS ADMIN_WH
    WITH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300             -- Suspend after 5 minutes of inactivity
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for administrative and maintenance tasks';

-- =====================================================
-- Verification
-- =====================================================

SHOW WAREHOUSES LIKE '%_WH';
