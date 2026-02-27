-- ========================================
-- SUPABASE SETUP FOR PERSONAL RESEARCH ASSISTANT
-- ========================================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ========================================
-- TABLE: research_documents
-- ========================================

CREATE TABLE research_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT NOT NULL,
  embedding VECTOR(768),
  metadata JSONB DEFAULT '{}'::jsonb,
  
  -- Auto-extracted metadata columns (populated by trigger)
  title TEXT,
  author TEXT,
  page_count INTEGER,
  word_count INTEGER,
  file_url TEXT,
  added_by TEXT,
  year INTEGER,
  metadata_source TEXT,
  added_date TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- TRIGGER: Auto-extract metadata from JSONB
-- ========================================

CREATE OR REPLACE FUNCTION extract_metadata_from_jsonb()
RETURNS TRIGGER AS $$
BEGIN
  NEW.title := NEW.metadata->>'title';
  NEW.author := NEW.metadata->>'author';
  NEW.page_count := (NEW.metadata->>'page_count')::integer;
  NEW.word_count := (NEW.metadata->>'word_count')::integer;
  NEW.file_url := NEW.metadata->>'file_url';
  NEW.added_by := NEW.metadata->>'added_by';
  NEW.year := (NEW.metadata->>'year')::integer;
  NEW.metadata_source := NEW.metadata->>'metadata_source';
  NEW.added_date := (NEW.metadata->>'added_date')::timestamptz;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER extract_metadata_trigger
  BEFORE INSERT OR UPDATE ON research_documents
  FOR EACH ROW
  EXECUTE FUNCTION extract_metadata_from_jsonb();

-- ========================================
-- TRIGGER: Auto-update timestamp
-- ========================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_research_documents_updated_at
  BEFORE UPDATE ON research_documents
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- INDEXES: research_documents
-- ========================================

-- Vector similarity search (cosine distance)
CREATE INDEX research_documents_embedding_idx 
ON research_documents 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Full-text search
CREATE INDEX research_documents_text_idx 
ON research_documents 
USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || content));

-- Metadata search
CREATE INDEX research_documents_metadata_idx 
ON research_documents 
USING gin(metadata);

-- Common query fields
CREATE INDEX research_documents_title_idx ON research_documents(title);
CREATE INDEX research_documents_author_idx ON research_documents(author);
CREATE INDEX research_documents_added_date_idx ON research_documents(added_date DESC);
CREATE INDEX research_documents_year_idx ON research_documents(year);

-- ========================================
-- TABLE: conversation_history
-- For Postgres Chat Memory (n8n AI Agent)
-- ========================================

CREATE TABLE conversation_history (
  id SERIAL PRIMARY KEY,
  session_id VARCHAR NOT NULL,
  type VARCHAR,
  data JSONB DEFAULT '{}'::jsonb
);

-- Index for fast session lookup
CREATE INDEX conversation_history_session_idx ON conversation_history(session_id);

-- ========================================
-- FUNCTION: match_documents
-- Used by n8n Supabase Vector Store node
-- ========================================

CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(768),
  match_count INT DEFAULT 3,
  filter JSONB DEFAULT '{}'
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  metadata JSONB,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    rd.id,
    rd.content,
    rd.metadata,
    1 - (rd.embedding <=> query_embedding) AS similarity
  FROM research_documents rd
  WHERE 1 - (rd.embedding <=> query_embedding) > 0.5
  ORDER BY rd.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ========================================
-- FUNCTION: get_document_stats
-- Useful for monitoring your library
-- ========================================

CREATE OR REPLACE FUNCTION get_document_stats()
RETURNS TABLE (
  total_documents BIGINT,
  total_pages BIGINT,
  total_words BIGINT,
  unique_authors BIGINT,
  earliest_year INTEGER,
  latest_year INTEGER,
  most_recent_addition TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT,
    SUM(rd.page_count)::BIGINT,
    SUM(rd.word_count)::BIGINT,
    COUNT(DISTINCT rd.author)::BIGINT,
    MIN(rd.year),
    MAX(rd.year),
    MAX(rd.added_date)
  FROM research_documents rd;
END;
$$;

-- ========================================
-- MAINTENANCE QUERIES
-- ========================================

-- View library stats
-- SELECT * FROM get_document_stats();

-- View all documents
-- SELECT id, title, author, year, page_count, added_date 
-- FROM research_documents 
-- ORDER BY added_date DESC;

-- Search by title
-- SELECT title, author, year FROM research_documents 
-- WHERE title ILIKE '%transformer%';

-- Search by author
-- SELECT title, year FROM research_documents 
-- WHERE author ILIKE '%vaswani%';

-- Find documents with missing metadata
-- SELECT id, title, metadata_source 
-- FROM research_documents 
-- WHERE author = 'Unknown' OR metadata_source = 'filename';

-- Cleanup old conversations (run monthly)
-- DELETE FROM conversation_history 
-- WHERE id IN (
--   SELECT id FROM conversation_history 
--   ORDER BY id DESC 
--   OFFSET 1000  -- Keep only last 1000 messages
-- );

-- Rebuild vector index (if needed after bulk inserts)
-- REINDEX INDEX research_documents_embedding_idx;

-- Optimize database performance
-- VACUUM ANALYZE research_documents;
-- VACUUM ANALYZE conversation_history;
