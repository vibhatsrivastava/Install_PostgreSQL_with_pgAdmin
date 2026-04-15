# pgVector Extension Guide

Enable vector similarity search capabilities in PostgreSQL for AI/ML applications.

## Overview

pgVector is a PostgreSQL extension that adds support for vector similarity search, essential for:

- **Semantic Search**: Find similar text based on meaning, not just keywords
- **Recommendation Systems**: Find similar items based on embeddings
- **AI/ML Applications**: Store and query high-dimensional vectors
- **Document Similarity**: Compare documents using vector representations
- **Image Recognition**: Store and search image embeddings

## Features

- ✅ Store vectors up to 16,000 dimensions
- ✅ Three distance operators: L2, inner product, cosine distance
- ✅ Indexing with IVFFlat and HNSW algorithms
- ✅ Compatible with popular AI models (OpenAI, Ollama, HuggingFace)
- ✅ Exact and approximate nearest neighbor search

## Prerequisites

- PostgreSQL installed (run `install_postgresql_pgadmin.sh` first)
- Root or sudo privileges

## Quick Start

### Installation

```bash
chmod +x install_pgvector.sh
sudo ./install_pgvector.sh
```

The script will:
1. Install required build dependencies
2. Clone and compile pgVector from source
3. Install the extension system-wide
4. Create the extension in your database

### Enable in Database

```sql
-- Connect to your database
\c myappdb

-- Create extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify installation
SELECT * FROM pg_extension WHERE extname = 'vector';
```

## Basic Usage

### Creating a Table with Vectors

```sql
-- Create table with vector column
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name TEXT,
    embedding vector(768)  -- 768 dimensions
);

-- Insert data
INSERT INTO items (name, embedding) VALUES
    ('Item 1', '[0.1, 0.2, 0.3, ...]'),  -- Array of 768 floats
    ('Item 2', '[0.4, 0.5, 0.6, ...]');
```

### Vector Operations

```sql
-- Calculate L2 distance (Euclidean)
SELECT name, embedding <-> '[0.1, 0.2, 0.3, ...]' AS distance
FROM items
ORDER BY distance
LIMIT 5;

-- Calculate cosine distance
SELECT name, embedding <=> '[0.1, 0.2, 0.3, ...]' AS distance
FROM items
ORDER BY distance
LIMIT 5;

-- Calculate inner product (negative for similarity)
SELECT name, embedding <#> '[0.1, 0.2, 0.3, ...]' AS distance
FROM items
ORDER BY distance
LIMIT 5;
```

## Distance Operators

| Operator | Description | Use Case |
|----------|-------------|----------|
| `<->` | L2 distance (Euclidean) | Absolute similarity |
| `<=>` | Cosine distance | Normalized similarity, text embeddings |
| `<#>` | Inner product (negative) | Recommendation systems |

## Indexing for Performance

### IVFFlat Index

Good for up to 1M vectors, faster build time:

```sql
-- Create index
CREATE INDEX ON items USING ivfflat (embedding vector_l2_ops) WITH (lists = 100);

-- For cosine distance
CREATE INDEX ON items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- For inner product
CREATE INDEX ON items USING ivfflat (embedding vector_ip_ops) WITH (lists = 100);
```

**Tuning:**
- `lists`: Square root of total rows (typical: 100-1000)
- More lists = faster search, slower build time

### HNSW Index

Better accuracy for large datasets (1M+ vectors):

```sql
-- Create HNSW index
CREATE INDEX ON items USING hnsw (embedding vector_l2_ops);

-- With custom parameters
CREATE INDEX ON items USING hnsw (embedding vector_cosine_ops) 
WITH (m = 16, ef_construction = 64);
```

**Tuning:**
- `m`: Higher = better recall, more memory (default: 16)
- `ef_construction`: Higher = better index quality (default: 64)

## Integration with CDC Replication

This is automatically configured when using `install_cdc_replication.sh`. Here's how it works:

### Automatic Embedding Generation

```sql
-- Function to generate embeddings via Ollama
CREATE OR REPLACE FUNCTION generate_embedding(text_input TEXT)
RETURNS vector AS $$
    import requests
    import json
    
    response = requests.post(
        'http://localhost:11434/api/embeddings',
        json={'model': 'nomic-embed-text', 'prompt': text_input}
    )
    
    embedding = response.json()['embedding']
    return embedding
$$ LANGUAGE plpython3u;

-- Trigger to auto-generate embeddings
CREATE TRIGGER generate_embedding_trigger
BEFORE INSERT OR UPDATE ON target_table
FOR EACH ROW
EXECUTE FUNCTION auto_generate_embedding();
```

### Querying Similar Records

```sql
-- Find similar error messages
SELECT 
    id,
    message,
    1 - (message_embedding <=> generate_embedding('connection timeout')) as similarity
FROM failed_jobs
WHERE message_embedding IS NOT NULL
ORDER BY message_embedding <=> generate_embedding('connection timeout')
LIMIT 10;
```

## Performance Best Practices

### 1. Choose Right Index Type

- **IVFFlat**: Up to 1M vectors, faster build
- **HNSW**: 1M+ vectors, better accuracy

### 2. Optimize Lists Parameter

```sql
-- Rule of thumb: lists ≈ sqrt(total_rows)
-- For 100,000 rows: lists = 316
-- For 1,000,000 rows: lists = 1000
```

### 3. Use Appropriate Distance Function

- **Cosine distance** (`<=>`): Best for text embeddings (normalized)
- **L2 distance** (`<->`): Absolute similarity
- **Inner product** (`<#>`): Pre-normalized vectors

### 4. Filter Before Search

```sql
-- Bad: Search then filter
SELECT * FROM items
WHERE embedding <-> '[...]' < 0.5
  AND category = 'electronics';

-- Good: Filter then search
SELECT * FROM items
WHERE category = 'electronics'
ORDER BY embedding <-> '[...]'
LIMIT 10;
```

### 5. Normalize Vectors

```sql
-- Normalize vector to unit length (for cosine similarity)
CREATE OR REPLACE FUNCTION normalize_vector(v vector)
RETURNS vector AS $$
    SELECT (v::real[] / sqrt((SELECT sum(x*x) FROM unnest(v::real[]) x)))::vector
$$ LANGUAGE SQL IMMUTABLE;
```

## Common Use Cases

### Semantic Text Search

```sql
-- Create table for documents
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    title TEXT,
    content TEXT,
    embedding vector(768)
);

-- Generate embeddings (using Ollama)
-- INSERT with embeddings generated via application or trigger

-- Search for similar documents
SELECT title, content
FROM documents
ORDER BY embedding <=> (SELECT embedding FROM some_query_vector)
LIMIT 10;
```

### Image Similarity Search

```sql
-- Create table for images
CREATE TABLE images (
    id SERIAL PRIMARY KEY,
    filename TEXT,
    embedding vector(512)  -- e.g., ResNet embeddings
);

-- Find similar images
SELECT filename
FROM images
ORDER BY embedding <-> '[...]'  -- Query image embedding
LIMIT 10;
```

### Product Recommendations

```sql
-- Create table for products
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    description TEXT,
    embedding vector(768)
);

-- Recommend similar products
SELECT name, description
FROM products
WHERE id != 123  -- Exclude current product
ORDER BY embedding <-> (SELECT embedding FROM products WHERE id = 123)
LIMIT 5;
```

## Monitoring and Maintenance

### Check Extension Version

```sql
SELECT * FROM pg_available_extensions WHERE name = 'vector';
```

### Index Statistics

```sql
-- Check index size
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE indexname LIKE '%vector%';
```

### Query Performance

```sql
-- Enable timing
\timing on

-- Analyze query plan
EXPLAIN ANALYZE
SELECT * FROM items
ORDER BY embedding <-> '[...]'
LIMIT 10;
```

## Troubleshooting

### Extension Not Found

```sql
-- Check if extension is available
SELECT * FROM pg_available_extensions WHERE name = 'vector';

-- If not found, reinstall
sudo ./install_pgvector.sh
```

### Index Not Being Used

```sql
-- Check if index exists
\d items

-- Rebuild index
DROP INDEX index_name;
CREATE INDEX ON items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Analyze table
ANALYZE items;
```

### Slow Queries

```sql
-- Increase probes for IVFFlat (session level)
SET ivfflat.probes = 10;  -- Default: 1

-- For HNSW, increase ef_search
SET hnsw.ef_search = 100;  -- Default: 40
```

### Dimension Mismatch Errors

```sql
-- Error: expected 768 dimensions, got 512
-- Ensure all vectors have same dimensions

-- Check dimensions
SELECT id, array_length(embedding::real[], 1) as dims
FROM items
WHERE array_length(embedding::real[], 1) != 768;
```

## Upgrading pgVector

```bash
# Check current version
sudo -u postgres psql -c "SELECT * FROM pg_extension WHERE extname = 'vector';"

# Upgrade extension
sudo ./install_pgvector.sh  # Reinstalls latest version

# Update in database
sudo -u postgres psql -d myappdb -c "ALTER EXTENSION vector UPDATE;"
```

## Further Reading

- **pgVector GitHub**: https://github.com/pgvector/pgvector
- **Distance Metrics**: https://github.com/pgvector/pgvector#distance
- **Indexing Strategies**: https://github.com/pgvector/pgvector#indexing
- **CDC Replication Guide**: [CDC_REPLICATION.md](CDC_REPLICATION.md)

---

**Related Documentation:**
- [CDC Replication Guide](CDC_REPLICATION.md)
- [Configuration Reference](CONFIGURATION.md)
- [Performance Tuning](PERFORMANCE_TUNING.md)
- [Back to Main README](../README.md)
