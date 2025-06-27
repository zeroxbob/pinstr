-- Create all databases from postgres database
CREATE DATABASE pinstr_production;
CREATE DATABASE pinstr_production_cache;
CREATE DATABASE pinstr_production_queue;
CREATE DATABASE pinstr_production_cable;

-- Grant all privileges to the pinstr user on all databases
GRANT ALL PRIVILEGES ON DATABASE pinstr_production TO pinstr;
GRANT ALL PRIVILEGES ON DATABASE pinstr_production_cache TO pinstr;
GRANT ALL PRIVILEGES ON DATABASE pinstr_production_queue TO pinstr;
GRANT ALL PRIVILEGES ON DATABASE pinstr_production_cable TO pinstr;
