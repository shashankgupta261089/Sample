create extension if not exists vector with schema extensions;

create table if not exists public.documents (
  id bigserial primary key,
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  embedding extensions.vector(1536)
);

create index if not exists documents_embedding_idx
on public.documents
using ivfflat (embedding extensions.vector_cosine_ops)
with (lists = 100);

drop function if exists public.match_documents(extensions.vector, integer, jsonb);

create or replace function public.match_documents (
  query_embedding extensions.vector(1536),
  match_count int default 5,
  filter jsonb default '{}'::jsonb
)
returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
begin
  return query
  select
    documents.id,
    documents.content,
    documents.metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from public.documents
  where documents.metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;
