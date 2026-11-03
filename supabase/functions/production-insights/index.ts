// CHANGLONG INTELLIGENCE Edge Function
// Rate limiting should be implemented at the API gateway / Supabase project settings level.
// Supabase does not support per-function rate limiting natively.
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const MAX_BODY_BYTES = 100 * 1024;

const ALLOWED_ROLES = new Set([
  "admin", "plant_director", "manager", "production_manager",
  "energy_manager", "maintenance_manager", "engineer", "safety_officer",
]);

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const contentLength = parseInt(req.headers.get("content-length") ?? "0", 10);
    if (contentLength > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } }
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Not authenticated" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await supabase.auth.getUser(token);
    if (userError || !userData.user) {
      return jsonResponse({ error: "Invalid session" }, 401);
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (!profile) {
      return jsonResponse({ error: "Profile not found" }, 403);
    }

    if (!ALLOWED_ROLES.has(profile.role)) {
      return jsonResponse({ error: "Insufficient permissions for this operation" }, 403);
    }

    const rawBody = await req.text();
    if (rawBody.length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }

    let parsedBody: { days?: unknown };
    try {
      parsedBody = JSON.parse(rawBody);
    } catch {
      parsedBody = { days: 30 };
    }

    const days = Number(parsedBody.days ?? 30);
    if (!Number.isInteger(days) || days < 1 || days > 365) {
      return jsonResponse({ error: "days must be a positive integer between 1 and 365" }, 400);
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    const dateStr = startDate.toISOString().split("T")[0];

    const { data: prodData } = await supabase
      .from("production_records")
      .select("record_date, output_weight_kg, rejected_weight_kg, target_weight_kg, shift_id")
      .gte("record_date", dateStr)
      .order("record_date", { ascending: true })
      .limit(500);

    const { data: shiftsData } = await supabase
      .from("shifts")
      .select("id, name");

    const shiftMap = new Map((shiftsData ?? []).map((s: { id: string; name: string }) => [s.id, s.name]));

    const records = prodData as Array<{
      record_date: string; output_weight_kg: number; rejected_weight_kg: number;
      target_weight_kg: number | null; shift_id: string | null;
    }> ?? [];

    const byDate = new Map<string, { output: number; rejected: number; target: number }>();
    for (const r of records) {
      const point = byDate.get(r.record_date) ?? { output: 0, rejected: 0, target: 0 };
      point.output += Number(r.output_weight_kg) || 0;
      point.rejected += Number(r.rejected_weight_kg) || 0;
      point.target += Number(r.target_weight_kg) || 0;
      byDate.set(r.record_date, point);
    }

    const dailyTrend = Array.from(byDate.entries()).map(([date, v]) => ({
      date,
      output_kg: Math.round(v.output),
      target_kg: Math.round(v.target),
      rejection_rate_pct: v.output > 0 ? Number(((v.rejected / v.output) * 100).toFixed(2)) : 0,
    }));

    const byShift = new Map<string, { output: number; rejected: number; count: number }>();
    for (const r of records) {
      const shiftName = r.shift_id ? (shiftMap.get(r.shift_id) ?? "Unknown") : "Unassigned";
      const point = byShift.get(shiftName) ?? { output: 0, rejected: 0, count: 0 };
      point.output += Number(r.output_weight_kg) || 0;
      point.rejected += Number(r.rejected_weight_kg) || 0;
      point.count += 1;
      byShift.set(shiftName, point);
    }

    const shiftPerformance = Array.from(byShift.entries()).map(([shift, v]) => ({
      shift,
      total_output_kg: Math.round(v.output),
      rejection_rate_pct: v.output > 0 ? Number(((v.rejected / v.output) * 100).toFixed(2)) : 0,
      record_count: v.count,
    }));

    const totalOutput = records.reduce((s, r) => s + Number(r.output_weight_kg || 0), 0);
    const totalRejected = records.reduce((s, r) => s + Number(r.rejected_weight_kg || 0), 0);
    const totalTarget = records.reduce((s, r) => s + Number(r.target_weight_kg || 0), 0);
    const targetAchievement = totalTarget > 0 ? (totalOutput / totalTarget) * 100 : null;
    const rejectionRate = totalOutput > 0 ? (totalRejected / totalOutput) * 100 : 0;

    const sorted = [...dailyTrend].sort((a, b) => b.output_kg - a.output_kg);
    const bestDay = sorted[0] ?? null;
    const worstDay = sorted[sorted.length - 1] ?? null;

    return jsonResponse({
      period: { days, startDate: dateStr },
      totals: {
        total_output_kg: Math.round(totalOutput),
        total_rejected_kg: Math.round(totalRejected),
        total_target_kg: Math.round(totalTarget),
        target_achievement_pct: targetAchievement !== null ? Number(targetAchievement.toFixed(1)) : null,
        rejection_rate_pct: Number(rejectionRate.toFixed(2)),
      },
      dailyTrend,
      shiftPerformance,
      highlights: {
        bestDay: bestDay ? { date: bestDay.date, output_kg: bestDay.output_kg } : null,
        worstDay: worstDay ? { date: worstDay.date, output_kg: worstDay.output_kg } : null,
      },
      dataSource: "database",
    }, 200);
  } catch {
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
