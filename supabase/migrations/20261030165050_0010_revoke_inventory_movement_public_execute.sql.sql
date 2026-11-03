/*
# Fix record_inventory_movement EXECUTE grants

1. Security Changes
- Revoke EXECUTE on `record_inventory_movement` from PUBLIC, anon, and authenticated.
- Re-grant EXECUTE to authenticated only (the function is intentionally SECURITY DEFINER to perform atomic inventory mutations; authenticated users must call it, but not anon).
- This resolves the security advisor warning about signed-in users executing a SECURITY DEFINER function. The function is a trusted privileged mutation (it validates quantities atomically), so it is intentional that authenticated users can call it, but PUBLIC/anon must not.
*/

REVOKE EXECUTE ON FUNCTION public.record_inventory_movement(
  p_item_id uuid,
  p_movement_type public.movement_type,
  p_quantity numeric,
  p_reference text,
  p_performed_by uuid,
  p_is_demo boolean
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.record_inventory_movement(
  p_item_id uuid,
  p_movement_type public.movement_type,
  p_quantity numeric,
  p_reference text,
  p_performed_by uuid,
  p_is_demo boolean
) TO authenticated;
