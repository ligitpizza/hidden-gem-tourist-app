create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if exists (
    select 1
      from pg_catalog.pg_extension as e
      join pg_catalog.pg_namespace as n on n.oid = e.extnamespace
     where e.extname = 'pgcrypto'
       and n.nspname <> 'extensions'
  ) then
    alter extension pgcrypto set schema extensions;
  end if;
end;
$$;

create table if not exists public.travel_vault_pin_credentials (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pin_hash text not null,
  pin_length smallint not null check (pin_length in (4, 6)),
  failed_attempts smallint not null default 0
    check (failed_attempts between 0 and 5),
  locked_until timestamptz,
  credential_version integer not null default 1
    check (credential_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.travel_vault_pin_credentials enable row level security;

revoke all on table public.travel_vault_pin_credentials
  from public, anon, authenticated;

create or replace function public.get_travel_vault_pin_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_credential public.travel_vault_pin_credentials%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
    into v_credential
    from public.travel_vault_pin_credentials
   where user_id = v_user_id;

  if not found then
    return jsonb_build_object('configured', false);
  end if;

  return jsonb_build_object(
    'configured', true,
    'pin_length', v_credential.pin_length,
    'locked_until', v_credential.locked_until,
    'credential_version', v_credential.credential_version
  );
end;
$$;

create or replace function public.set_travel_vault_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_version integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_pin is null or p_pin !~ '^([0-9]{4}|[0-9]{6})$' then
    raise exception 'PIN must contain 4 or 6 digits'
      using errcode = '22023';
  end if;

  insert into public.travel_vault_pin_credentials (
    user_id,
    pin_hash,
    pin_length,
    failed_attempts,
    locked_until,
    credential_version,
    updated_at
  ) values (
    v_user_id,
    extensions.crypt(p_pin, extensions.gen_salt('bf', 12)),
    length(p_pin),
    0,
    null,
    1,
    now()
  )
  on conflict (user_id) do update
    set pin_hash = excluded.pin_hash,
        pin_length = excluded.pin_length,
        failed_attempts = 0,
        locked_until = null,
        credential_version =
          public.travel_vault_pin_credentials.credential_version + 1,
        updated_at = now()
  returning credential_version into v_version;

  return jsonb_build_object(
    'result', 'written',
    'credential_version', v_version
  );
end;
$$;

create or replace function public.verify_travel_vault_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_credential public.travel_vault_pin_credentials%rowtype;
  v_failed_attempts integer;
  v_locked_until timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
    into v_credential
    from public.travel_vault_pin_credentials
   where user_id = v_user_id
   for update;

  if not found then
    return jsonb_build_object('result', 'not_configured');
  end if;

  if v_credential.locked_until is not null
      and v_credential.locked_until > now() then
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds',
        greatest(1, ceil(extract(epoch from
          (v_credential.locked_until - now())))::integer),
      'credential_version', v_credential.credential_version
    );
  end if;

  if v_credential.locked_until is not null then
    update public.travel_vault_pin_credentials
       set failed_attempts = 0,
           locked_until = null,
           updated_at = now()
     where user_id = v_user_id;
    v_credential.failed_attempts := 0;
  end if;

  if v_credential.pin_hash = extensions.crypt(p_pin, v_credential.pin_hash) then
    update public.travel_vault_pin_credentials
       set failed_attempts = 0,
           locked_until = null,
           updated_at = now()
     where user_id = v_user_id;

    return jsonb_build_object(
      'result', 'verified',
      'credential_version', v_credential.credential_version
    );
  end if;

  v_failed_attempts := least(v_credential.failed_attempts + 1, 5);
  v_locked_until := case
    when v_failed_attempts >= 5 then now() + interval '5 minutes'
    else null
  end;

  update public.travel_vault_pin_credentials
     set failed_attempts = v_failed_attempts,
         locked_until = v_locked_until,
         updated_at = now()
   where user_id = v_user_id;

  if v_locked_until is not null then
    return jsonb_build_object(
      'result', 'locked',
      'retry_after_seconds', 300,
      'credential_version', v_credential.credential_version
    );
  end if;

  return jsonb_build_object(
    'result', 'incorrect',
    'attempts_remaining', 5 - v_failed_attempts,
    'credential_version', v_credential.credential_version
  );
end;
$$;

revoke all on function public.get_travel_vault_pin_status()
  from public, anon;
revoke all on function public.set_travel_vault_pin(text)
  from public, anon;
revoke all on function public.verify_travel_vault_pin(text)
  from public, anon;

grant execute on function public.get_travel_vault_pin_status()
  to authenticated;
grant execute on function public.set_travel_vault_pin(text)
  to authenticated;
grant execute on function public.verify_travel_vault_pin(text)
  to authenticated;
