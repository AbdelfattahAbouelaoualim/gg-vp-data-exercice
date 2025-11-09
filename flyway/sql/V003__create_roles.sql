-- =====================================================
-- Flyway Migration V003: Create RBAC Roles
-- Description: Create role-based access control structure
-- Author: Data Engineering Team
-- Date: 2025-11-08
-- =====================================================

-- Note: This should be run with SECURITYADMIN or ACCOUNTADMIN role

-- =====================================================
-- Functional Roles (Human Users)
-- =====================================================

-- Data Engineers: Full access to DEV, controlled access to PROD
CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Data engineers with full development access';

-- Data Analysts: Read-only access to marts and observability
CREATE ROLE IF NOT EXISTS DATA_ANALYST
    COMMENT = 'Data analysts with read-only access to marts';

-- Product Owners: Read-only access to marts and observability for monitoring
CREATE ROLE IF NOT EXISTS PRODUCT_OWNER
    COMMENT = 'Product owners with read access to marts and observability';

-- External Clients: Restricted read-only access to specific marts views
CREATE ROLE IF NOT EXISTS CLIENT_VIEWER
    COMMENT = 'External clients with restricted read-only access';

-- =====================================================
-- Service Account Roles (Automation)
-- =====================================================

-- DBT Runner: Automated dbt transformations
CREATE ROLE IF NOT EXISTS DBT_RUNNER
    COMMENT = 'Service account for dbt transformations';

-- Flyway Deployer: Database migrations
CREATE ROLE IF NOT EXISTS FLYWAY_DEPLOYER
    COMMENT = 'Service account for Flyway database migrations';

-- CI/CD Pipeline: GitHub Actions automation
CREATE ROLE IF NOT EXISTS CICD_PIPELINE
    COMMENT = 'Service account for CI/CD automation';

-- =====================================================
-- Role Hierarchy (Inheritance)
-- =====================================================

-- Data Engineer inherits Data Analyst (can do everything an analyst can + more)
GRANT ROLE DATA_ANALYST TO ROLE DATA_ENGINEER;

-- Data Engineer can use DBT_RUNNER capabilities
GRANT ROLE DBT_RUNNER TO ROLE DATA_ENGINEER;

-- CI/CD Pipeline can use DBT_RUNNER and FLYWAY_DEPLOYER
GRANT ROLE DBT_RUNNER TO ROLE CICD_PIPELINE;
GRANT ROLE FLYWAY_DEPLOYER TO ROLE CICD_PIPELINE;

-- =====================================================
-- Grant roles to SYSADMIN (for centralized management)
-- =====================================================

GRANT ROLE DATA_ENGINEER TO ROLE SYSADMIN;
GRANT ROLE DATA_ANALYST TO ROLE SYSADMIN;
GRANT ROLE PRODUCT_OWNER TO ROLE SYSADMIN;
GRANT ROLE CLIENT_VIEWER TO ROLE SYSADMIN;
GRANT ROLE DBT_RUNNER TO ROLE SYSADMIN;
GRANT ROLE FLYWAY_DEPLOYER TO ROLE SYSADMIN;
GRANT ROLE CICD_PIPELINE TO ROLE SYSADMIN;

-- =====================================================
-- Verification
-- =====================================================

SHOW ROLES LIKE 'DATA_%' ;
SHOW ROLES LIKE '%_RUNNER';
SHOW ROLES LIKE '%_DEPLOYER';
SHOW ROLES LIKE 'CICD_%';
SHOW ROLES LIKE 'CLIENT_%';
