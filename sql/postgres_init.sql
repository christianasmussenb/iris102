-- PostgreSQL Initialization Script for IRIS102 Demo
-- Creates the records table for CSV data ingestion

-- Drop table if exists for clean setup
DROP TABLE IF EXISTS records;

-- Create main records table
CREATE TABLE records (
    id SERIAL PRIMARY KEY,
    external_id VARCHAR(64) NOT NULL,
    name VARCHAR(200) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    occurred_at TIMESTAMP NOT NULL,
    source_file VARCHAR(255) NOT NULL,
    file_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create unique index to prevent duplicates
CREATE UNIQUE INDEX uq_records_extid_date ON records (external_id, occurred_at);

-- Create index for file hash (for duplicate detection)
CREATE INDEX idx_records_file_hash ON records (file_hash);

-- Create index for source file
CREATE INDEX idx_records_source_file ON records (source_file);

-- Create function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_records_updated_at 
    BEFORE UPDATE ON records 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for testing
INSERT INTO records (external_id, name, amount, occurred_at, source_file, file_hash) VALUES
('SAMPLE001', 'Sample Record 1', 100.50, '2025-10-14 10:00:00', 'sample_init.csv', 'init_hash_001'),
('SAMPLE002', 'Sample Record 2', 250.75, '2025-10-14 10:15:00', 'sample_init.csv', 'init_hash_001');

-- Show created table structure
\d records;

-- Show initial data
SELECT COUNT(*) as initial_record_count FROM records;