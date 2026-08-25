-- Lets a tourist undo a "save" (the bookmark toggle on the discovery
-- feed) by deleting their own save rows for that place. Deliberately
-- scoped to interaction_type = 'save' only -- view/search stay
-- append-only, real history for Smart Preference Learning; only the
-- explicit, user-visible "I bookmarked this" action is reversible,
-- matching the bookmark icon's toggle affordance in the UI.
create policy "tourists remove their own save interactions"
  on public.user_interactions
  for delete
  using (auth.uid() = user_id and interaction_type = 'save');
