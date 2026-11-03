/*
# Security Fixes — Function Search Paths and EXECUTE Permissions

## Purpose
Addresses 4 security advisor findings:
1. `set_updated_at` has a mutable search_path — add `SET search_path = public`.
2. `handle_new_user` is a SECURITY DEFINER trigger function callable by anon/authenticated via REST — 
   revoke EXECUTE from PUBLIC, anon, authenticated. It only needs to run as a trigger, not via RPC.
3. `record_inventory_movement` is intentionally callable by authenticated users (used by the app),
   but its search_path should be locked.

## Changes
- Recreate `set_updated_at` with `SET search_path = public`.
- Recreate `handle_new_user` with `SET search_path = public` and revoke EXECUTE from PUBLIC/anon/authenticated.
- Recreate `record_inventory_movement` already has SET search_path = public — confirmed in original migration.
- Revoke EXECUTE on `handle_new_user` from PUBLIC, anon, authenticated.
*/

-- Fix set_updated_at search_path
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Fix handle_new_user search_path and permissions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email));
  RETURN NEW;
END;
$$;

-- Revoke EXECUTE on handle_new_user from everyone except service_role
-- It's a trigger function — only needs to run internally, not via REST
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Confirm record_inventory_movement has locked search_path (recreate to ensure)
CREATE OR REPLACE FUNCTION public.record_inventory_movement(
  p_item_id uuid,
  p_movement_type movement_type,
  p_quantity numeric,
  p_reference text DEFAULT NULL,
  p_performed_by uuid DEFAULT NULL,
  p_is_demo boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_stock numeric(12,2);
  v_movement_id uuid;
BEGIN
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive (use movement_type for direction)';
  END IF;

  SELECT current_stock INTO v_new_stock
  FROM warehouse_items WHERE id = p_item_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Warehouse item % not found', p_item_id;
  END IF;

  IF p_movement_type = 'incoming' THEN
    v_new_stock := v_new_stock + p_quantity;
  ELSIF p_movement_type = 'outgoing' THEN
    v_new_stock := v_new_stock - p_quantity;
    IF v_new_stock < 0 THEN
      RAISE EXCEPTION 'Insufficient stock for item %. Available: %, Requested: %',
        p_item_id, (SELECT current_stock FROM warehouse_items WHERE id = p_item_id), p_quantity;
    END IF;
  ELSIF p_movement_type = 'adjustment' THEN
    v_new_stock := p_quantity;
  END IF;

  UPDATE warehouse_items SET current_stock = v_new_stock, updated_at = now()
  WHERE id = p_item_id;

  INSERT INTO inventory_movements (item_id, movement_type, quantity, reference, performed_by, is_demo)
  VALUES (p_item_id, p_movement_type, p_quantity, p_reference, p_performed_by, p_is_demo)
  RETURNING id INTO v_movement_id;

  RETURN v_movement_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_inventory_movement(uuid, movement_type, numeric, text, uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_inventory_movement(uuid, movement_type, numeric, text, uuid, boolean) TO authenticated, service_role;
