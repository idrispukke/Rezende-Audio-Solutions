-- Lista tabelas do schema public SEM Row Level Security.
-- Rode no SQL Editor do Supabase. Resultado esperado: 0 linhas.
-- Qualquer linha aqui = tabela exposta publicamente pela anon key.

select c.relname as tabela
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relrowsecurity = false
order by 1;
