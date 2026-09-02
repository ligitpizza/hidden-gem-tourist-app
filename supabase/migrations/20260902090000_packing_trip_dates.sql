alter table public.packing_checklist_states
  add column if not exists trip_start_date date,
  add column if not exists trip_end_date date;

alter table public.packing_checklist_states
  drop constraint if exists packing_checklist_states_trip_date_order;

alter table public.packing_checklist_states
  add constraint packing_checklist_states_trip_date_order
  check (
    (trip_start_date is null and trip_end_date is null)
    or (
      trip_start_date is not null
      and trip_end_date is not null
      and trip_end_date >= trip_start_date
    )
  );
