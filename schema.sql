-- SurplusLink backend. Paste this whole file into Supabase > SQL Editor > Run.
create extension if not exists pgcrypto;

create table profiles(
  id uuid primary key references auth.users on delete cascade,
  role text not null check (role in ('donor','ngo','admin')),
  name text not null, lat double precision, lng double precision, capacity int,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now());

create table requests(
  id uuid primary key default gen_random_uuid(),
  donor_id uuid not null references profiles(id), ngo_id uuid not null references profiles(id),
  food text, kg numeric, meals int, mins int,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','enroute','collected','locked')),
  ngo_lat double precision, ngo_lng double precision, bad int not null default 0,
  created_at timestamptz default now());

-- The pickup code lives here. Only the donor can read it; the NGO can only test a guess via verify_pickup().
create table request_codes(request_id uuid primary key references requests(id) on delete cascade, donor_id uuid not null, code text not null);

alter table profiles enable row level security;
alter table requests enable row level security;
alter table request_codes enable row level security;

create function is_admin() returns boolean language sql security definer set search_path=public stable as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin' and status='approved') $$;

create policy p_ins on profiles for insert to authenticated with check (id=auth.uid() and status='pending');
create policy p_sel on profiles for select to authenticated using (
  id=auth.uid() or is_admin() or (role='ngo' and status='approved')
  or id in (select donor_id from requests where ngo_id=auth.uid()));
create policy p_upd on profiles for update to authenticated using (is_admin()) with check (is_admin());

create policy r_sel on requests for select to authenticated using (donor_id=auth.uid() or ngo_id=auth.uid() or is_admin());
create policy r_ins on requests for insert to authenticated with check (
  donor_id=auth.uid() and status='pending' and bad=0 and ngo_lat is null
  and exists(select 1 from profiles where id=auth.uid() and role='donor' and status='approved')
  and exists(select 1 from profiles where id=ngo_id and role='ngo' and status='approved'));
create policy r_upd on requests for update to authenticated using (ngo_id=auth.uid()) with check (ngo_id=auth.uid());
create policy c_sel on request_codes for select to authenticated using (donor_id=auth.uid());

-- NGOs may accept, reject, start and share location, but never mark a pickup collected themselves.
create function guard_req() returns trigger language plpgsql as $$
begin
  if current_setting('app.verify',true)='1' then return new; end if;
  if new.status in ('collected','locked') or new.bad<>old.bad or new.donor_id<>old.donor_id or new.ngo_id<>old.ngo_id then
    raise exception 'not allowed'; end if;
  return new;
end $$;
create trigger t_guard before update on requests for each row execute function guard_req();

create function new_code() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into request_codes values(new.id,new.donor_id,
    lpad((100000+abs(('x'||encode(gen_random_bytes(4),'hex'))::bit(32)::bigint)%900000)::text,6,'0'));
  return new;
end $$;
create trigger t_code after insert on requests for each row execute function new_code();

create function verify_pickup(rid uuid, c text) returns text language plpgsql security definer set search_path=public as $$
declare r requests; k text;
begin
  select * into r from requests where id=rid and ngo_id=auth.uid() and status='enroute';
  if not found then return 'invalid'; end if;
  select code into k from request_codes where request_id=rid;
  perform set_config('app.verify','1',true);
  if k=c then update requests set status='collected' where id=rid; return 'ok'; end if;
  update requests set bad=bad+1, status=case when bad+1>=3 then 'locked' else status end where id=rid;
  return case when r.bad+1>=3 then 'locked' else 'wrong' end;
end $$;
grant execute on function verify_pickup(uuid,text) to authenticated;

alter publication supabase_realtime add table requests, profiles;

-- FIRST ADMIN: sign up on the site, register as "Admin", then run this once with your email:
-- update profiles set status='approved' where id=(select id from auth.users where email='YOU@EXAMPLE.COM');
