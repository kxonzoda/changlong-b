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

    let parsedBody: { equipment_id?: string; hours?: unknown };
    try {
      parsedBody = JSON.parse(rawBody);
    } catch {
      parsedBody = { equipment_id: null, hours: 24 };
    }

    const { equipment_id, hours = 24 } = parsedBody;
    if (!equipment_id) {
      return jsonResponse({ error: "equipment_id is required" }, 400);
    }

    const hoursNum = Number(hours);
    if (!Number.isInteger(hoursNum) || hoursNum < 1 || hoursNum > 720) {
      return jsonResponse({ error: "hours must be a positive integer between 1 and 720" }, 400);
    }

    const startTime = new Date();
    startTime.setHours(startTime.getHours() - hoursNum);

    const { data: telemetry, error: telemError } = await supabase
      .from("equipment_telemetry")
      .select("*")
      .eq("equipment_id", equipment_id)
      .gte("reading_time", startTime.toISOString())
      .order("reading_time", { ascending: true })
      .limit(1000);

    if (telemError) throw new Error("Telemetry query failed");

    const { data: equipment } = await supabase
      .from("equipment")
      .select("*")
      .eq("id", equipment_id)
      .maybeSingle();

    if (!equipment) {
      return jsonResponse({ error: "Equipment not found" }, 404);
    }

    const byMetric = new Map<string, Array<{ time: string; value: number }>>();
    for (const row of telemetry ?? []) {
      const arr = byMetric.get(row.metric) ?? [];
      arr.push({ time: row.reading_time, value: Number(row.value) });
      byMetric.set(row.metric, arr);
    }

    const anomalies: Array<{ metric: string; value: number; mean: number; stddev: number; zScore: number; severity: string }> = [];
    const summaries: Array<{ metric: string; count: number; mean: number; min: number; max: number; stddev: number; lastValue: number }> = [];

    for (const [metric, readings] of byMetric) {
      const values = readings.map((r) => r.value);
      if (values.length < 2) continue;

      const mean = values.reduce((s, v) => s + v, 0) / values.length;
      const variance = values.reduce((s, v) => s + Math.pow(v - mean, 2), 0) / values.length;
      const stddev = Math.sqrt(variance);
      const lastValue = values[values.length - 1];
      const min = Math.min(...values);
      const max = Math.max(...values);

      summaries.push({ metric, count: values.length, mean: Number(mean.toFixed(3)), min: Number(min.toFixed(3)), max: Number(max.toFixed(3)), stddev: Number(stddev.toFixed(3)), lastValue: Number(lastValue.toFixed(3)) });

      if (stddev > 0) {
        const zScore = (lastValue - mean) / stddev;
        if (Math.abs(zScore) > 2) {
          anomalies.push({
            metric,
            value: lastValue,
            mean: Number(mean.toFixed(3)),
            stddev: Number(stddev.toFixed(3)),
            zScore: Number(zScore.toFixed(2)),
            severity: Math.abs(zScore) > 3 ? "critical" : "warning",
          });
        }
      }

      const recentCount = Math.max(Math.floor(values.length * 0.2), 3);
      const recent = values.slice(-recentCount);
      const recentMean = recent.reduce((s, v) => s + v, 0) / recent.length;
      if (stddev > 0 && Math.abs(recentMean - mean) > stddev) {
        anomalies.push({
          metric,
          value: Number(recentMean.toFixed(3)),
          mean: Number(mean.toFixed(3)),
          stddev: Number(stddev.toFixed(3)),
          zScore: Number(((recentMean - mean) / stddev).toFixed(2)),
          severity: "trend",
        });
      }
    }

    let riskScore = 0;
    if (equipment.health_score < 60) riskScore += 40;
    else if (equipment.health_score < 80) riskScore += 20;

    const criticalAnomalies = anomalies.filter((a) => a.severity === "critical").length;
    const warningAnomalies = anomalies.filter((a) => a.severity === "warning").length;
    riskScore += criticalAnomalies * 25 + warningAnomalies * 10;
    riskScore = Math.min(riskScore, 100);

    const riskLevel = riskScore >= 70 ? "high" : riskScore >= 40 ? "medium" : "low";

    const recommendations: string[] = [];
    if (equipment.health_score < 70) {
      recommendations.push(`Equipment health score is ${equipment.health_score}%. Schedule preventive maintenance inspection.`);
    }
    if (criticalAnomalies > 0) {
      recommendations.push(`${criticalAnomalies} critical anomaly(ies) detected. Immediate investigation recommended.`);
    }
    if (warningAnomalies > 0) {
      recommendations.push(`${warningAnomalies} warning-level anomaly(ies) detected. Monitor closely.`);
    }
    if (anomalies.some((a) => a.severity === "trend")) {
      recommendations.push("Trending deviation detected in recent readings. Check for progressive wear or environmental changes.");
    }
    if (recommendations.length === 0) {
      recommendations.push("No anomalies detected. Equipment operating within normal parameters.");
    }

    return jsonResponse({
      equipment: {
        code: equipment.equipment_code,
        name: equipment.name,
        status: equipment.status,
        healthScore: equipment.health_score,
      },
      analysis: {
        hoursAnalyzed: hoursNum,
        totalReadings: telemetry?.length ?? 0,
        metrics: summaries,
        anomalies,
        anomalyCount: anomalies.length,
      },
      riskAssessment: {
        score: riskScore,
        level: riskLevel,
        recommendations,
      },
      dataSource: "database",
      note: "Statistical analysis based on z-score and trend detection. Not a verified ML prediction.",
    }, 200);
  } catch {
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
