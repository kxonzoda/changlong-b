/*
# Phase 3 Security Remediation

## Summary

This migration fixes the two critical vulnerabilities and two high-severity issues
identified in the Phase 3 security audit:

1. **CRITICAL: record_inventory_movement missing authorization** — Any authenticated
   user (including viewer) could adjust stock. Now requires admin, plant_director,
   manager, or warehouse_manager role. performed_by is derived from auth.uid().

2. **CRITICAL: iot-ingestion device authentication** — Creates a device_credentials
   table for secure API-key-based device authentication with per-equipment and
   per-meter authorization scoping.

3. **HIGH: admin_update_profile broken audit insert** — The function referenced
   nonexistent old_values/new_values columns on audit_logs. Now stores old/new
   values inside the existing details JSONB column.

4. **MEDIUM: log_audit_event user attribution** — The function accepted any
   p_user_id, allowing audit log forgery. Now derives the actor from auth.uid()
   and validates action/entity_type are non-empty.

## New Tables

### device_credentials
Stores hashed API keys for IoT device authentication. Each credential is scoped
to a specific equipment_id and/or meter_id. The API key itself is never stored —
only its SHA-256 hash. Credentials can be deactivated (revoked) via is_active.

Columns:
- id (uuid, PK)
- device_id (text, unique) — the device identifier sent in ingestion payloads
- api_key_hash (text, not null) — SHA-256 hash of the provisioning API key
- equipment_id (uuid, nullable FK) — equipment this device may write telemetry for
- meter_id (uuid, nullable FK) — energy meter this device may write readings for
- is_active (boolean, default true) — set false to revoke
- last_used_at (timestamptz, nullable) — updated on each successful authentication
- created_at (timestamptz, default now())
- updated_at (timestamptz, default now())

## Modified Functions

### record_inventory_movement
- Added auth.uid() check (raises exception if null)
- Added role check: admin, plant_director, manager, warehouse_manager
- p_performed_by is now ignored; performed_by is always auth.uid()
- All existing validation (quantity > 0, stock sufficiency, FOR UPDATE lock) preserved

### admin_update_profile
- Audit INSERT now uses details JSONB column with {old, new} structure
- All existing protections (self-role-change prevention, role check) preserved

### log_audit_event
- p_user_id is now overridden with auth.uid() (prevents forged attribution)
- Added validation: p_action and p_entity_type must be non-empty
- Role check preserved (admin, plant_director, manager only)

## Security Changes
- RLS enabled on device_credentials
- service_role granted ALL on device_credentials (edge function access)
- No authenticated/anon grants on device_credentials (device auth is separate from user auth)
- EXECUTE on all modified functions remains granted to authenticated only
*/

-- ============================================================
-- 1. Create device_credentials table
-- ============================================================

CREATE TABLE IF NOT EXISTS device_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text UNIQUE NOT NULL,
  api_key_hash text NOT NULL,
  equipment_id uuid REFERENCES equipment(id) ON DELETE SET NULL,
  meter_id uuid REFERENCES energy_meters(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  last_used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE device_credentials ENABLE ROW LEVEL SECURITY;

-- Only service_role can access device_credentials (edge function uses service role)
-- No authenticated/anon access — device provisioning is an admin operation
GRANT ALL ON device_credentials TO service_role;

-- ============================================================
-- 2. Fix record_inventory_movement — add authorization
-- ============================================================

CREATE OR REPLACE FUNCTION public.record_inventory_movement(
  p_item_id uuid,
  p_movement_type movement_type,
  p_quantity numeric,
  p_reference text DEFAULT NULL::text,
  p_performed_by uuid DEFAULT NULL::uuid,
  p_is_demo boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid;
  v_caller_role user_role;
  v_new_stock numeric(12,2);
  v_movement_id uuid;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director', 'manager', 'warehouse_manager') THEN
    RAISE EXCEPTION 'Permission denied: warehouse management role required';
  END IF;

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
  VALUES (p_item_id, p_movement_type, p_quantity, p_reference, v_caller_id, p_is_demo)
  RETURNING id INTO v_movement_id;

  RETURN v_movement_id;
END;
$function$;

-- ============================================================
-- 3. Fix admin_update_profile — audit log column reference
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_update_profile(
  p_target_user_id uuid,
  p_role user_role DEFAULT NULL::user_role,
  p_is_active boolean DEFAULT NULL::boolean,
  p_department_id uuid DEFAULT NULL::uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_id uuid;
  v_caller_role user_role;
  v_old_values jsonb;
  v_new_values jsonb := '{}'::jsonb;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director') THEN
    RAISE EXCEPTION 'Permission denied: admin or plant_director role required';
  END IF;

  IF p_role IS NOT NULL AND v_caller_id = p_target_user_id THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;

  SELECT to_jsonb(t) INTO v_old_values
  FROM (SELECT role, is_active, department_id FROM profiles WHERE id = p_target_user_id) t;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  IF p_role IS NOT NULL THEN
    UPDATE profiles SET role = p_role WHERE id = p_target_user_id;
    v_new_values := v_new_values || jsonb_build_object('role', p_role);
  END IF;

  IF p_is_active IS NOT NULL THEN
    UPDATE profiles SET is_active = p_is_active WHERE id = p_target_user_id;
    v_new_values := v_new_values || jsonb_build_object('is_active', p_is_active);
  END IF;

  IF p_department_id IS NOT NULL THEN
    UPDATE profiles SET department_id = p_department_id WHERE id = p_target_user_id;
    v_new_values := v_new_values || jsonb_build_object('department_id', p_department_id);
  END IF;

  INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
  VALUES (
    v_caller_id,
    CASE
      WHEN p_role IS NOT NULL THEN 'role_change'
      WHEN p_is_active IS NOT NULL AND p_is_active = false THEN 'user_deactivate'
      WHEN p_is_active IS NOT NULL AND p_is_active = true THEN 'user_activate'
      ELSE 'profile_update'
    END,
    'profiles',
    p_target_user_id,
    jsonb_build_object('old', v_old_values, 'new', v_new_values)
  );

  RETURN true;
END;
$function$;

-- ============================================================
-- 4. Fix log_audit_event — prevent forged attribution
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_audit_event(
  p_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid DEFAULT NULL::uuid,
  p_details jsonb DEFAULT NULL::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_log_id uuid;
  v_caller_id uuid;
  v_caller_role user_role;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'plant_director', 'manager') THEN
    RAISE EXCEPTION 'Permission denied: insufficient role to write audit logs';
  END IF;

  IF p_action IS NULL OR btrim(p_action) = '' THEN
    RAISE EXCEPTION 'Action cannot be empty';
  END IF;

  IF p_entity_type IS NULL OR btrim(p_entity_type) = '' THEN
    RAISE EXCEPTION 'Entity type cannot be empty';
  END IF;

  INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
  VALUES (
    v_caller_id,
    p_action,
    p_entity_type,
    p_entity_id,
    COALESCE(p_details, jsonb_build_object('attributed_user_id', p_user_id))
  )
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$function$;

-- ============================================================
-- 5. Fix equipment UPDATE policy — engineer in WITH CHECK
-- ============================================================

DROP POLICY IF EXISTS "equip_update_mgmt" ON equipment;

CREATE POLICY "equip_update_mgmt"
ON equipment FOR UPDATE
TO authenticated
USING (EXISTS (
  SELECT 1 FROM profiles p
  WHERE p.id = auth.uid()
  AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager', 'engineer')
))
WITH CHECK (EXISTS (
  SELECT 1 FROM profiles p
  WHERE p.id = auth.uid()
  AND p.role IN ('admin', 'plant_director', 'manager', 'maintenance_manager', 'engineer')
));
