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

const EMISSION_FACTORS = {
  electricity_kgco2_per_kwh: 0.581,
  natural_gas_kgco2_per_m3: 2.16,
};

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

    const { data: energyData, error: energyError } = await supabase
      .from("energy_consumption_daily")
      .select("consumption_date, total_value, meter:energy_meters(energy_type)")
      .gte("consumption_date", dateStr)
      .order("consumption_date", { ascending: true })
      .limit(500);

    if (energyError) throw new Error("Energy query failed");

    const { data: prodData } = await supabase
      .from("production_records")
      .select("record_date, output_weight_kg")
      .gte("record_date", dateStr)
      .limit(500);

    const byDate = new Map<string, { electricity: number; gas: number; water: number; air: number }>();
    for (const row of energyData as unknown as Array<{
      consumption_date: string; total_value: number; meter: { energy_type: string } | null;
    }>) {
      const point = byDate.get(row.consumption_date) ?? { electricity: 0, gas: 0, water: 0, air: 0 };
      const type = row.meter?.energy_type;
      if (type === "electricity") point.electricity += Number(row.total_value) || 0;
      else if (type === "natural_gas") point.gas += Number(row.total_value) || 0;
      else if (type === "water") point.water += Number(row.total_value) || 0;
      else if (type === "compressed_air") point.air += Number(row.total_value) || 0;
      byDate.set(row.consumption_date, point);
    }

    const totalElec = Array.from(byDate.values()).reduce((s, p) => s + p.electricity, 0);
    const totalGas = Array.from(byDate.values()).reduce((s, p) => s + p.gas, 0);
    const totalWater = Array.from(byDate.values()).reduce((s, p) => s + p.water, 0);
    const totalOutputKg = (prodData as Array<{ output_weight_kg: number }>)?.reduce((s, r) => s + Number(r.output_weight_kg || 0), 0) ?? 0;

    const energyIntensity = totalOutputKg > 0 ? totalElec / (totalOutputKg / 1000) : null;

    const estimatedCo2Elec = totalElec * EMISSION_FACTORS.electricity_kgco2_per_kwh;
    const estimatedCo2Gas = totalGas * EMISSION_FACTORS.natural_gas_kgco2_per_m3;
    const totalEstimatedCo2 = estimatedCo2Elec + estimatedCo2Gas;

    const dailyElec = Array.from(byDate.values()).map((p) => p.electricity);
    const peakElec = dailyElec.length > 0 ? Math.max(...dailyElec) : 0;
    const avgElec = dailyElec.length > 0 ? dailyElec.reduce((s, v) => s + v, 0) / dailyElec.length : 0;
    const peakDeviation = avgElec > 0 ? ((peakElec - avgElec) / avgElec) * 100 : 0;

    const anomalyDays = dailyElec.filter((v) => avgElec > 0 && v > avgElec * 1.3).length;

    return jsonResponse({
      period: { days, startDate: dateStr },
      totals: {
        electricity_kwh: Math.round(totalElec),
        natural_gas_m3: Math.round(totalGas),
        water_m3: Math.round(totalWater),
      },
      energyIntensity: energyIntensity !== null ? Number(energyIntensity.toFixed(2)) : null,
      energyIntensityUnit: "kWh per tonne of steel",
      estimatedCo2: {
        fromElectricity_kg: Math.round(estimatedCo2Elec),
        fromGas_kg: Math.round(estimatedCo2Gas),
        total_kg: Math.round(totalEstimatedCo2),
        note: "Estimates using IPCC reference emission factors. Not verified plant measurements.",
        factors: EMISSION_FACTORS,
      },
      peak: {
        electricity_kwh: Math.round(peakElec),
        average_kwh: Math.round(avgElec),
        deviation_pct: Number(peakDeviation.toFixed(1)),
      },
      anomalies: {
        highConsumptionDays: anomalyDays,
        threshold: "30% above daily average",
      },
      dataSource: "database",
    }, 200);
  } catch {
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
