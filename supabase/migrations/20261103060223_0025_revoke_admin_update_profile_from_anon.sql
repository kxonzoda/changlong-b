-- Phase 4.2 P0 Remediation: Revoke EXECUTE on admin_update_profile from anon
--
-- Security finding: anon role had EXECUTE privilege on admin_update_profile,
-- a SECURITY DEFINER function that can modify user profiles, roles, and
-- active status. Although the function body checks auth.uid() and caller
-- role internally, the anon role should never have execute grants on
-- privileged admin functions — defense in depth.
--
-- This revokes EXECUTE from anon and PUBLIC. authenticated retains access
-- (the function's internal authorization check still gates actual execution
-- to admin and plant_director roles).

REVOKE EXECUTE ON FUNCTION public.admin_update_profile(uuid, user_role, boolean, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_update_profile(uuid, user_role, boolean, uuid) FROM PUBLIC;
