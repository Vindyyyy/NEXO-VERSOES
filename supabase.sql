-- NEXO: rede de pets (piloto em família).
-- Cole tudo isto no "SQL Editor" do seu projeto Supabase e clique em "Run". Pode rodar de novo sem problema.
-- Segurança: cada linha pertence a um grupo. O banco só deixa ler e escrever as linhas do grupo
-- cujo código secreto veio no pedido (cabeçalho x-grupo). Quem não tem o convite não vê nada.

create table if not exists public.membros (
  id uuid primary key,
  grupo text not null,
  nome text not null,
  pet text,
  criado timestamptz not null default now()
);

create table if not exists public.recados (
  id uuid primary key,
  grupo text not null,
  de uuid not null,
  para uuid not null,
  texto text not null check (char_length(texto) <= 600),
  prazo date,
  urgente boolean not null default false,
  estado text not null default 'novo' check (estado in ('novo','depois','feito','ajuda')),
  criado timestamptz not null default now(),
  respondido timestamptz
);

create table if not exists public.itens (
  id uuid primary key,
  grupo text not null,
  texto text not null check (char_length(texto) <= 200),
  tipo text not null default 'compra' check (tipo in ('compra','tarefa')),
  dono uuid,
  feito boolean not null default false,
  feito_por uuid,
  criado timestamptz not null default now(),
  atualizado timestamptz not null default now()
);

-- Versão 0.9.15: compromissos e tarefas da família com data (pode rodar de novo sem problema).
alter table public.itens add column if not exists quando timestamptz;
alter table public.itens add column if not exists tem_hora boolean not null default false;
alter table public.itens drop constraint if exists itens_tipo_check;
alter table public.itens add constraint itens_tipo_check check (tipo in ('compra','tarefa','evento'));

-- Versão 0.9.17: tarefas que dependem de outras (demandas interligadas).
alter table public.itens add column if not exists depende_de uuid;

create index if not exists recados_grupo on public.recados (grupo, para);
create index if not exists itens_grupo on public.itens (grupo);
create index if not exists membros_grupo on public.membros (grupo);

-- O código do grupo vem no cabeçalho do pedido.
create or replace function public.grupo_do_pedido() returns text
language sql stable as $$
  select coalesce(current_setting('request.headers', true)::json ->> 'x-grupo', '')
$$;

alter table public.membros enable row level security;
alter table public.recados enable row level security;
alter table public.itens enable row level security;

drop policy if exists "so_do_grupo" on public.membros;
drop policy if exists "so_do_grupo" on public.recados;
drop policy if exists "so_do_grupo" on public.itens;

create policy "so_do_grupo" on public.membros for all
  using (grupo = public.grupo_do_pedido() and length(grupo) >= 16)
  with check (grupo = public.grupo_do_pedido() and length(grupo) >= 16);
create policy "so_do_grupo" on public.recados for all
  using (grupo = public.grupo_do_pedido() and length(grupo) >= 16)
  with check (grupo = public.grupo_do_pedido() and length(grupo) >= 16);
create policy "so_do_grupo" on public.itens for all
  using (grupo = public.grupo_do_pedido() and length(grupo) >= 16)
  with check (grupo = public.grupo_do_pedido() and length(grupo) >= 16);

grant select, insert, update, delete on public.membros, public.recados, public.itens to anon;
