-- PostgreSQL initialization script for n8n
-- This script runs on first container start with empty data directory

-- Create the n8n database if it doesn't exist
-- Note: The database is typically created by POSTGRES_DB env var,
-- but this ensures proper configuration

-- Grant all privileges to the n8n user on the n8n database
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;

-- Set default timezone
SET timezone = 'America/New_York';

-- Ensure the n8n user can create tables
ALTER USER n8n CREATEDB;
