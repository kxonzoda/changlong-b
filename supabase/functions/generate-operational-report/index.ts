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

    const [prodRes, energyRes, equipRes, maintRes, safetyRes, qualityRes, envRes] = await Promise.all([
      supabase.from("production_records")
        .select("record_date, output_weight_kg, rejected_weight_kg, target_weight_kg")
        .gte("record_date", dateStr)
        .order("record_date", { ascending: true })
        .limit(500),
      supabase.from("energy_consumption_daily")
        .select("consumption_date, total_value, meter:energy_meters(energy_type)")
        .gte("consumption_date", dateStr)
        .order("consumption_date", { ascending: true })
        .limit(500),
      supabase.from("equipment")
        .select("equipment_code, name, status, health_score, operating_hours")
        .limit(100),
      supabase.from("maintenance_work_orders")
        .select("work_order_number, type, priority, status, cost, downtime_hours")
        .order("created_at", { ascending: false })
        .limit(50),
      supabase.from("safety_incidents")
        .select("incident_number, title, severity, status")
        .order("incident_date", { ascending: false })
        .limit(50),
      supabase.from("quality_inspections")
        .select("inspection_number, result, steel_grade")
        .gte("inspection_date", dateStr)
        .limit(200),
      supabase.from("emission_records")
        .select("emission_type, emission_date, value, unit")
        .gte("emission_date", dateStr)
        .order("emission_date", { ascending: true })
        .limit(200),
    ]);

    const prodData = prodRes.data as Array<{ output_weight_kg: number; rejected_weight_kg: number; target_weight_kg: number }>;
    const totalOutput = prodData.reduce((s, r) => s + Number(r.output_weight_kg || 0), 0);
    const totalRejected = prodData.reduce((s, r) => s + Number(r.rejected_weight_kg || 0), 0);
    const totalTarget = prodData.reduce((s, r) => s + Number(r.target_weight_kg || 0), 0);
    const targetAchievement = totalTarget > 0 ? (totalOutput / totalTarget) * 100 : null;
    const rejectionRate = totalOutput > 0 ? (totalRejected / totalOutput) * 100 : 0;

    const energyData = energyRes.data as Array<{ total_value: number; meter: { energy_type: string } | null }>;
    const totalElec = energyData.filter((r) => r.meter?.energy_type === "electricity").reduce((s, r) => s + Number(r.total_value || 0), 0);
    const energyIntensity = totalOutput > 0 ? totalElec / (totalOutput / 1000) : null;

    const equipData = equipRes.data as Array<{ status: string; health_score: number }>;
    const operational = equipData.filter((e) => e.status === "operational").length;
    const avgHealth = equipData.length > 0 ? equipData.reduce((s, e) => s + e.health_score, 0) / equipData.length : 0;
    const availability = equipData.length > 0 ? (operational / equipData.length) * 100 : 0;

    const maintData = maintRes.data as Array<{ status: string; cost: number; downtime_hours: number; type: string; priority: string }>;
    const completedWO = maintData.filter((w) => w.status === "completed").length;
    const totalWO = maintData.length;
    const completionRate = totalWO > 0 ? (completedWO / totalWO) * 100 : 0;
    const totalCost = maintData.reduce((s, w) => s + Number(w.cost || 0), 0);
    const totalDowntime = maintData.reduce((s, w) => s + Number(w.downtime_hours || 0), 0);
    const criticalCount = maintData.filter((w) => w.priority === "critical" && w.status !== "completed").length;

    const safetyData = safetyRes.data as Array<{ status: string; severity: string }>;
    const openIncidents = safetyData.filter((i) => i.status === "reported" || i.status === "investigating").length;
    const criticalIncidents = safetyData.filter((i) => i.severity === "critical").length;

    const qualData = qualityRes.data as Array<{ result: string }>;
    const qualityPassRate = qualData.length > 0
      ? (qualData.filter((q) => q.result === "pass").length / qualData.length) * 100
      : null;

    const envData = envRes.data as Array<{ emission_type: string; value: number }>;
    const co2Total = envData.filter((e) => e.emission_type === "co2").reduce((s, e) => s + Number(e.value || 0), 0);

    const report = {
      reportDate: new Date().toISOString(),
      period: { days, startDate: dateStr },
      production: {
        totalOutputKg: Math.round(totalOutput),
        totalRejectedKg: Math.round(totalRejected),
        targetAchievementPct: targetAchievement !== null ? Number(targetAchievement.toFixed(1)) : null,
        rejectionRatePct: Number(rejectionRate.toFixed(2)),
      },
      energy: {
        totalElectricityKwh: Math.round(totalElec),
        energyIntensity: energyIntensity !== null ? Number(energyIntensity.toFixed(1)) : null,
        energyIntensityUnit: "kWh per tonne",
      },
      equipment: {
        totalUnits: equipData.length,
        operational,
        availabilityPct: Number(availability.toFixed(0)),
        avgHealthScore: Number(avgHealth.toFixed(0)),
      },
      maintenance: {
        totalWorkOrders: totalWO,
        completed: completedWO,
        completionRatePct: Number(completionRate.toFixed(1)),
        totalCost: Math.round(totalCost),
        totalDowntimeHours: Number(totalDowntime.toFixed(0)),
        criticalOpen: criticalCount,
      },
      safety: {
        openIncidents,
        criticalIncidents,
      },
      quality: {
        totalInspections: qualData.length,
        passRatePct: qualityPassRate !== null ? Number(qualityPassRate.toFixed(1)) : null,
      },
      environmental: {
        estimatedCo2Kg: Math.round(co2Total),
        note: "CO2 estimates using IPCC reference emission factors",
      },
      dataSource: "database",
    };

    const aiApiKey = Deno.env.get("AI_API_KEY");
    const aiProvider = Deno.env.get("AI_PROVIDER");

    if (aiApiKey && aiProvider) {
      try {
        const summary = await generateNarrativeReport(aiProvider, aiApiKey, report);
        return jsonResponse({ ...report, narrativeSummary: summary, source: `${aiProvider}-llm` }, 200);
      } catch {
        // fall through to rule-based summary
      }
    }

    const summary = [
      `OPERATIONAL REPORT — ${days} days (database records)`,
      ``,
      `PRODUCTION: ${(totalOutput / 1000).toFixed(1)} tonnes produced, ${rejectionRate.toFixed(2)}% rejection rate, ${targetAchievement?.toFixed(1) ?? 'N/A'}% target achievement.`,
      `ENERGY: ${totalElec.toFixed(0)} kWh consumed, ${energyIntensity?.toFixed(1) ?? 'N/A'} kWh/tonne intensity.`,
      `EQUIPMENT: ${availability.toFixed(0)}% availability, ${avgHealth.toFixed(0)} average health score.`,
      `MAINTENANCE: ${completionRate.toFixed(1)}% completion rate, $${totalCost.toFixed(0)} total cost, ${totalDowntime.toFixed(0)}h downtime.`,
      `SAFETY: ${openIncidents} open incidents, ${criticalIncidents} critical.`,
      `QUALITY: ${qualityPassRate?.toFixed(1) ?? 'N/A'}% pass rate across ${qualData.length} inspections.`,
      `ENVIRONMENT: ${co2Total.toFixed(0)} kg estimated CO2 emissions.`,
      ``,
      `NOTE: Rule-based summary from current database records. Configure an AI provider for narrative report generation.`,
    ].join("\n");

    return jsonResponse({ ...report, narrativeSummary: summary, source: "rule-based" }, 200);
  } catch {
    return jsonResponse({ error: "Internal error" }, 500);
  }
});

async function generateNarrativeReport(provider: string, apiKey: string, report: unknown): Promise<string> {
  if (provider !== "openai" && provider !== "groq") {
    throw new Error("Unsupported AI provider");
  }

  const baseUrl = Deno.env.get("AI_BASE_URL") ?? (provider === "groq" ? "https://api.groq.com/openai/v1" : "https://api.openai.com/v1");
  const model = Deno.env.get("AI_MODEL") ?? (provider === "groq" ? "llama-3.3-70b-versatile" : "gpt-4o-mini");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${apiKey}` },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: "Generate a concise executive operational report summary from the provided database records. Distinguish observed data from estimates and recommendations. Never invent measurements." },
          { role: "user", content: JSON.stringify(report, null, 2) },
        ],
        max_tokens: 500,
      }),
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`AI provider error: ${res.status}`);
    const data: unknown = await res.json();
    const content = (data as { choices?: Array<{ message?: { content?: unknown } }> }).choices?.[0]?.message?.content;
    if (typeof content !== "string" || content.trim().length === 0 || content.length > 8000) {
      throw new Error("AI provider returned an invalid response");
    }
    return content.trim();
  } finally {
    clearTimeout(timeout);
  }
}
