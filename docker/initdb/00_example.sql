-- ============================================================================
--  docker/initdb/00_example.sql
--
--  Files in this directory run inside PostgreSQL's entrypoint the FIRST time a
--  fresh pg-data volume is initialised (in alphabetical order, .sql/.sh). They
--  are SKIPPED when the volume already holds a cluster — re-run init with
--      docker compose -f docker/docker-compose.yml down -v && up -d
--
--  This example only records the schemas the rtos-manager service is expected
--  to use later. Adjust or add numbered files (01_..., 02_...) as the real
--  migrations land; keep application-level migrations authoritative elsewhere.
-- ============================================================================

-- Ensure a predictable schema to hang future tables on.
CREATE SCHEMA IF NOT EXISTS rtos;

-- Example placeholder so the schema is exercised on first boot. Replace with
-- real DDL once the persistence layer is designed.
-- CREATE TABLE IF NOT EXISTS rtos.device (
--   id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
--   name        TEXT        NOT NULL,
--   created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
-- );
