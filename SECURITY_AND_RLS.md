# Security & RLS — CHANGLONG INTELLIGENCE

## RLS Policy Summary

Every table has RLS enabled. The anon key client cannot read any operational data unless authenticated.

### Policy Patterns

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| departments | All authenticated | service_role only | service_role only | service_role only |
| profiles | Own row + admins read all | Trigger auto-creates | Own row only | service_role only |
| shifts | All authenticated | service_role only | service_role only | service_role only |
| employees | Admins/managers only | service_role only | service_role only | service_role only |
| production_lines | All authenticated | service_role only | service_role only | service_role only |
| production_batches | All authenticated | service_role only | service_role only | service_role only |
| production_records | All authenticated | service_role only | service_role only | service_role only |
| production_targets | All authenticated | service_role only | service_role only | service_role only |
| energy_meters | All authenticated | service_role only | service_role only | service_role only |
| energy_readings | All authenticated | service_role only | service_role only | service_role only |
| energy_consumption_daily | All authenticated | service_role only | service_role only | service_role only |
| equipment_categories | All authenticated | service_role only | service_role only | service_role only |
| equipment | All authenticated | service_role only | service_role only | service_role only |
| equipment_telemetry | All authenticated | service_role only | service_role only | service_role only |
| maintenance_work_orders | All authenticated | service_role only | service_role only | service_role only |
| maintenance_schedules | All authenticated | service_role only | service_role only | service_role only |
| warehouse_categories | All authenticated | service_role only | service_role only | service_role only |
| warehouse_items | All authenticated | service_role only | service_role only | service_role only |
| inventory_movements | All authenticated | service_role only | service_role only | service_role only |
| safety_incidents | Admins/managers/safety_officer only | service_role only | service_role only | service_role only |
| notifications | Owner only (auth.uid = user_id) | service_role only | Owner only | service_role only |
| audit_logs | Admins/plant_director only | service_role only | service_role only | service_role only |

### Sensitive Data Restrictions

- **Safety incidents**: Only `admin`, `plant_director`, `manager`, `safety_officer` roles can SELECT. Others get zero rows.
- **Employees**: Only `admin`, `plant_director`, `manager` roles can SELECT.
- **Audit logs**: Only `admin`, `plant_director` roles can SELECT. No user can modify audit records.
- **Notifications**: Users can only see and update their own notifications.

### Role Assignment Security

- New users get `role = 'viewer'` by default via the `handle_new_user()` trigger.
- Users **cannot** change their own role — the profiles UPDATE policy only allows updating your own row, and the frontend service layer only exposes `full_name`, `phone`, and `language` for self-update.
- Role changes require service_role access (admin edge function or direct database admin action).

### SECURITY DEFINER Functions

| Function | search_path | EXECUTE granted to |
|----------|-----------|-------------------|
| handle_new_user() | public | Nobody (trigger only) |
| set_updated_at() | public | All roles (default trigger) |
| record_inventory_movement() | public | authenticated, service_role |

### Grants Summary

- **authenticated**: SELECT on all operational tables. UPDATE on own profile and own notifications. EXECUTE on record_inventory_movement.
- **anon**: No grants on any application table (app requires sign-in).
- **service_role**: Full CRUD on all tables (used by edge functions with service_role key).

### Secrets

- No service_role keys, AI API keys, or credentials appear in frontend code.
- The frontend uses only the Supabase anon key with authenticated user sessions.
- Edge functions access the service_role key via `Deno.env.get()` server-side only.
- AI provider keys (AI_API_KEY, AI_PROVIDER) are accessed server-side only in the ai-analyst edge function.

## Security Advisor Results

After migration 0005, the Supabase security advisor reported 0 critical findings. All 4 original warnings were resolved:
1. `set_updated_at` — search_path locked to public.
2. `handle_new_user` — search_path locked, EXECUTE revoked from anon/authenticated.
3. `record_inventory_movement` — search_path confirmed locked.
