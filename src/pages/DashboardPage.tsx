import { useEffect, useState } from 'react';
import {
  AreaChart, Area, BarChart, Bar, LineChart, Line,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts';
import {
  Factory, Zap, Activity, ShieldAlert, Wrench, Package, AlertTriangle,
  TrendingUp, Gauge, ClipboardCheck, Leaf, FlaskConical,
} from 'lucide-react';
import type { DashboardTab } from '@/components/Sidebar';
import { KpiCard } from '@/components/KpiCard';
import { getKpiSummary } from '@/services/overviewService';
import { getProductionTrend, getProductionRecords } from '@/services/productionService';
import { getEnergyTrend, getEnergyMeters } from '@/services/energyService';
import { getEquipment } from '@/services/equipmentService';
import { getWorkOrders } from '@/services/maintenanceService';
import { getSafetyIncidents } from '@/services/safetyService';
import { getWarehouseItems } from '@/services/warehouseService';
import { getProductionLines, getDepartments } from '@/services/organizationService';
import { getQualityInspections, getQualityStandards, getQualityStats } from '@/services/qualityService';
import { getEnvironmentalReadings, getEmissionRecords, getWasteRecords } from '@/services/environmentService';
import type {
  KpiSummary, ProductionTrendPoint, EnergyTrendPoint,
  Equipment, MaintenanceWorkOrder, SafetyIncident, WarehouseItem,
  ProductionLine, Department, EnergyMeter, ProductionRecord,
  QualityInspection, QualityStandard, EnvironmentalReading, EmissionRecord, WasteRecord,
} from '@/types/database';

const statusColors: Record<string, string> = {
  operational: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
  under_maintenance: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
  idle: 'bg-slate-500/10 text-slate-400 border-slate-500/20',
  fault: 'bg-red-500/10 text-red-400 border-red-500/20',
  decommissioned: 'bg-slate-700/10 text-slate-500 border-slate-700/20',
};

const priorityColors: Record<string, string> = {
  critical: 'bg-red-500/10 text-red-400 border-red-500/20',
  high: 'bg-orange-500/10 text-orange-400 border-orange-500/20',
  medium: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
  low: 'bg-slate-500/10 text-slate-400 border-slate-500/20',
};

const severityColors: Record<string, string> = {
  critical: 'bg-red-500/10 text-red-400 border-red-500/20',
  serious: 'bg-orange-500/10 text-orange-400 border-orange-500/20',
  moderate: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
  minor: 'bg-slate-500/10 text-slate-400 border-slate-500/20',
};

const energyTypeColors: Record<string, string> = {
  electricity: '#f59e0b',
  natural_gas: '#3b82f6',
  water: '#06b6d4',
  compressed_air: '#8b5cf6',
};

function formatNumber(n: number): string {
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(2) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(1) + 'K';
  return n.toFixed(0);
}

function formatDate(dateStr: string): string {
  const d = new Date(dateStr);
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

function Badge({ text, className }: { text: string; className: string }) {
  return (
    <span className={`inline-block px-2 py-0.5 rounded-md text-xs font-medium border ${className}`}>
      {text}
    </span>
  );
}

export function DashboardPage({ tab }: { tab: DashboardTab }) {
  const [kpi, setKpi] = useState<KpiSummary | null>(null);
  const [prodTrend, setProdTrend] = useState<ProductionTrendPoint[]>([]);
  const [energyTrend, setEnergyTrend] = useState<EnergyTrendPoint[]>([]);
  const [equipment, setEquipment] = useState<Equipment[]>([]);
  const [workOrders, setWorkOrders] = useState<MaintenanceWorkOrder[]>([]);
  const [incidents, setIncidents] = useState<SafetyIncident[]>([]);
  const [warehouseItems, setWarehouseItems] = useState<WarehouseItem[]>([]);
  const [productionLines, setProductionLines] = useState<ProductionLine[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [energyMeters, setEnergyMeters] = useState<EnergyMeter[]>([]);
  const [prodRecords, setProdRecords] = useState<ProductionRecord[]>([]);
  const [qualityInspections, setQualityInspections] = useState<QualityInspection[]>([]);
  const [qualityStandards, setQualityStandards] = useState<QualityStandard[]>([]);
  const [qualityStats, setQualityStats] = useState<{ total: number; passed: number; failed: number; conditional: number; passRate: number } | null>(null);
  const [envReadings, setEnvReadings] = useState<EnvironmentalReading[]>([]);
  const [emissions, setEmissions] = useState<EmissionRecord[]>([]);
  const [wasteRecords, setWasteRecords] = useState<WasteRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError(null);

    const loads: Promise<unknown>[] = [];

    if (tab === 'overview') {
      loads.push(
        getKpiSummary(30).then((d) => active && setKpi(d)),
        getProductionTrend(30).then((d) => active && setProdTrend(d)),
        getEnergyTrend(30).then((d) => active && setEnergyTrend(d)),
        getEquipment().then((d) => active && setEquipment(d)),
        getWorkOrders(10).then((d) => active && setWorkOrders(d)),
      );
    } else if (tab === 'production') {
      loads.push(
        getProductionTrend(30).then((d) => active && setProdTrend(d)),
        getProductionRecords(30).then((d) => active && setProdRecords(d)),
        getProductionLines().then((d) => active && setProductionLines(d)),
      );
    } else if (tab === 'energy') {
      loads.push(
        getEnergyTrend(30).then((d) => active && setEnergyTrend(d)),
        getEnergyMeters().then((d) => active && setEnergyMeters(d)),
      );
    } else if (tab === 'equipment') {
      loads.push(
        getEquipment().then((d) => active && setEquipment(d)),
      );
    } else if (tab === 'maintenance') {
      loads.push(
        getWorkOrders(50).then((d) => active && setWorkOrders(d)),
      );
    } else if (tab === 'safety') {
      loads.push(
        getSafetyIncidents(50).then((d) => active && setIncidents(d)),
        getDepartments().then((d) => active && setDepartments(d)),
      );
    } else if (tab === 'quality') {
      loads.push(
        getQualityInspections(50).then((d) => active && setQualityInspections(d)),
        getQualityStandards().then((d) => active && setQualityStandards(d)),
        getQualityStats().then((d) => active && setQualityStats(d)),
      );
    } else if (tab === 'environment') {
      loads.push(
        getEnvironmentalReadings(30).then((d) => active && setEnvReadings(d)),
        getEmissionRecords(30).then((d) => active && setEmissions(d)),
        getWasteRecords(30).then((d) => active && setWasteRecords(d)),
      );
    } else if (tab === 'warehouse') {
      loads.push(
        getWarehouseItems().then((d) => active && setWarehouseItems(d)),
      );
    }

    Promise.all(loads)
      .catch((err) => active && setError(err instanceof Error ? err.message : 'Failed to load data'))
      .finally(() => active && setLoading(false));

    return () => { active = false; };
  }, [tab]);

  if (loading) {
    return (
      <div className="flex-1 flex items-center justify-center bg-slate-950">
        <div className="flex flex-col items-center gap-3">
          <Activity className="w-8 h-8 text-amber-500 animate-pulse" />
          <p className="text-slate-500 text-sm">Loading plant data...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex-1 flex items-center justify-center bg-slate-950">
        <div className="text-center max-w-md">
          <AlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-3" />
          <p className="text-red-400 font-medium mb-1">Failed to load data</p>
          <p className="text-slate-500 text-sm">{error}</p>
        </div>
      </div>
    );
  }

  const deptMap = new Map(departments.map((d) => [d.id, d.name]));
  const lineMap = new Map(productionLines.map((l) => [l.id, l.name]));

  return (
    <div className="flex-1 bg-slate-950 overflow-y-auto">
      <div className="p-6 max-w-7xl mx-auto">
        {tab === 'overview' && (
          <OverviewTab kpi={kpi} prodTrend={prodTrend} energyTrend={energyTrend} equipment={equipment} workOrders={workOrders} />
        )}
        {tab === 'production' && (
          <ProductionTab trend={prodTrend} records={prodRecords} lines={productionLines} />
        )}
        {tab === 'energy' && (
          <EnergyTab trend={energyTrend} meters={energyMeters} deptMap={deptMap} />
        )}
        {tab === 'equipment' && (
          <EquipmentTab equipment={equipment} deptMap={deptMap} lineMap={lineMap} />
        )}
        {tab === 'maintenance' && (
          <MaintenanceTab workOrders={workOrders} />
        )}
        {tab === 'quality' && (
          <QualityTab inspections={qualityInspections} standards={qualityStandards} stats={qualityStats} />
        )}
        {tab === 'safety' && (
          <SafetyTab incidents={incidents} deptMap={deptMap} />
        )}
        {tab === 'warehouse' && (
          <WarehouseTab items={warehouseItems} />
        )}
        {tab === 'environment' && (
          <EnvironmentTab readings={envReadings} emissions={emissions} waste={wasteRecords} />
        )}
      </div>
    </div>
  );
}

function OverviewTab({ kpi, prodTrend, energyTrend, equipment, workOrders }: {
  kpi: KpiSummary | null;
  prodTrend: ProductionTrendPoint[];
  energyTrend: EnergyTrendPoint[];
  equipment: Equipment[];
  workOrders: MaintenanceWorkOrder[];
}) {
  if (!kpi) return null;
  const activeWorkOrders = workOrders.filter((w) => w.status !== 'completed' && w.status !== 'cancelled');

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Plant Overview</h2>
        <p className="text-slate-400 text-sm mt-1">Key performance indicators — last 30 days</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <KpiCard
          label="Steel Output"
          value={formatNumber(kpi.totalOutputKg)}
          unit="kg"
          icon={<Factory className="w-5 h-5" />}
          accent="amber"
          trendLabel="30-day total"
        />
        <KpiCard
          label="Energy Consumption"
          value={formatNumber(kpi.energyConsumptionKwh)}
          unit="kWh"
          icon={<Zap className="w-5 h-5" />}
          accent="blue"
          trendLabel="Electricity, 30-day total"
        />
        <KpiCard
          label="Energy Intensity"
          value={kpi.energyIntensity.toFixed(1)}
          unit="kWh/t"
          icon={<TrendingUp className="w-5 h-5" />}
          accent="purple"
          trendLabel="kWh per tonne of steel"
        />
        <KpiCard
          label="Equipment Availability"
          value={kpi.equipmentAvailability.toFixed(0)}
          unit="%"
          icon={<Gauge className="w-5 h-5" />}
          accent="green"
          trendLabel={`${equipment.filter((e) => e.status === 'operational').length} of ${equipment.length} operational`}
        />
        <KpiCard
          label="Open Safety Incidents"
          value={String(kpi.openSafetyIncidents)}
          icon={<ShieldAlert className="w-5 h-5" />}
          accent="red"
          trendLabel="Requires investigation"
        />
        <KpiCard
          label="Critical Maintenance"
          value={String(kpi.criticalMaintenance)}
          icon={<Wrench className="w-5 h-5" />}
          accent="amber"
          trendLabel="High/critical priority"
        />
        <KpiCard
          label="Low Stock Items"
          value={String(kpi.lowStockItems)}
          icon={<Package className="w-5 h-5" />}
          accent="red"
          trendLabel="Below minimum threshold"
        />
        <KpiCard
          label="Active Work Orders"
          value={String(activeWorkOrders.length)}
          icon={<Wrench className="w-5 h-5" />}
          accent="blue"
          trendLabel="Open or in progress"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <ChartCard title="Production Output vs Target" subtitle="Daily, last 30 days">
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={prodTrend}>
              <defs>
                <linearGradient id="outputGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis dataKey="date" tickFormatter={formatDate} stroke="#64748b" fontSize={11} />
              <YAxis tickFormatter={formatNumber} stroke="#64748b" fontSize={11} />
              <Tooltip
                contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', fontSize: '12px' }}
                labelStyle={{ color: '#94a3b8' }}
              />
              <Area type="monotone" dataKey="output_kg" stroke="#f59e0b" fill="url(#outputGrad)" name="Output (kg)" strokeWidth={2} />
              <Line type="monotone" dataKey="target_kg" stroke="#64748b" name="Target (kg)" strokeDasharray="5 5" strokeWidth={1.5} />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Energy Consumption" subtitle="By type, last 30 days">
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={energyTrend}>
              <defs>
                <linearGradient id="elecGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f59e0b" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#f59e0b" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gasGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis dataKey="date" tickFormatter={formatDate} stroke="#64748b" fontSize={11} />
              <YAxis tickFormatter={formatNumber} stroke="#64748b" fontSize={11} />
              <Tooltip
                contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', fontSize: '12px' }}
                labelStyle={{ color: '#94a3b8' }}
              />
              <Legend wrapperStyle={{ fontSize: '11px' }} />
              <Area type="monotone" dataKey="electricity" stroke="#f59e0b" fill="url(#elecGrad)" name="Electricity (kWh)" strokeWidth={2} />
              <Area type="monotone" dataKey="gas" stroke="#3b82f6" fill="url(#gasGrad)" name="Gas (m3)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <DataCard title="Equipment Status" subtitle={`${equipment.length} units monitored`}>
          <div className="space-y-2">
            {equipment.slice(0, 6).map((eq) => (
              <div key={eq.id} className="flex items-center justify-between py-2 border-b border-slate-800 last:border-0">
                <div>
                  <p className="text-white text-sm font-medium">{eq.name}</p>
                  <p className="text-slate-500 text-xs">{eq.equipment_code}</p>
                </div>
                <div className="flex items-center gap-3">
                  <div className="text-right">
                    <p className="text-slate-400 text-xs">Health</p>
                    <p className={`text-sm font-semibold ${eq.health_score >= 80 ? 'text-emerald-400' : eq.health_score >= 60 ? 'text-amber-400' : 'text-red-400'}`}>
                      {eq.health_score}%
                    </p>
                  </div>
                  <Badge text={eq.status.replace(/_/g, ' ')} className={statusColors[eq.status] ?? ''} />
                </div>
              </div>
            ))}
          </div>
        </DataCard>

        <DataCard title="Recent Maintenance" subtitle="Latest work orders">
          <div className="space-y-2">
            {workOrders.slice(0, 6).map((wo) => (
              <div key={wo.id} className="flex items-center justify-between py-2 border-b border-slate-800 last:border-0">
                <div>
                  <p className="text-white text-sm font-medium">{wo.work_order_number}</p>
                  <p className="text-slate-500 text-xs truncate max-w-xs">{wo.description}</p>
                </div>
                <div className="flex items-center gap-2">
                  <Badge text={wo.priority} className={priorityColors[wo.priority] ?? ''} />
                  <Badge text={wo.status.replace(/_/g, ' ')} className="bg-slate-700/30 text-slate-400 border-slate-700" />
                </div>
              </div>
            ))}
          </div>
        </DataCard>
      </div>
    </div>
  );
}

function ProductionTab({ trend, records, lines }: {
  trend: ProductionTrendPoint[];
  records: ProductionRecord[];
  lines: ProductionLine[];
}) {
  const totalOutput = trend.reduce((s, p) => s + p.output_kg, 0);
  const totalTarget = trend.reduce((s, p) => s + p.target_kg, 0);
  const totalRejected = records.reduce((s, r) => s + Number(r.rejected_weight_kg), 0);
  const efficiency = totalTarget > 0 ? (totalOutput / totalTarget) * 100 : 0;
  const rejectionRate = totalOutput > 0 ? (totalRejected / totalOutput) * 100 : 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Production Management</h2>
        <p className="text-slate-400 text-sm mt-1">Steel output, target achievement, and batch tracking</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard label="30-Day Output" value={formatNumber(totalOutput)} unit="kg" icon={<Factory className="w-5 h-5" />} accent="amber" />
        <KpiCard label="Target Achievement" value={efficiency.toFixed(1)} unit="%" icon={<TrendingUp className="w-5 h-5" />} accent="green" />
        <KpiCard label="Rejection Rate" value={rejectionRate.toFixed(2)} unit="%" icon={<AlertTriangle className="w-5 h-5" />} accent="red" />
        <KpiCard label="Active Lines" value={String(lines.length)} icon={<Factory className="w-5 h-5" />} accent="blue" />
      </div>

      <ChartCard title="Daily Production Output vs Target" subtitle="Last 30 days, all lines">
        <ResponsiveContainer width="100%" height={320}>
          <BarChart data={trend}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
            <XAxis dataKey="date" tickFormatter={formatDate} stroke="#64748b" fontSize={11} />
            <YAxis tickFormatter={formatNumber} stroke="#64748b" fontSize={11} />
            <Tooltip
              contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', fontSize: '12px' }}
              labelStyle={{ color: '#94a3b8' }}
            />
            <Legend wrapperStyle={{ fontSize: '11px' }} />
            <Bar dataKey="output_kg" fill="#f59e0b" name="Output (kg)" radius={[4, 4, 0, 0]} />
            <Bar dataKey="target_kg" fill="#334155" name="Target (kg)" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </ChartCard>

      <DataCard title="Recent Production Records" subtitle={`${records.length} records, last 30 days`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Date</th>
                <th className="py-2 pr-4 font-medium">Steel Grade</th>
                <th className="py-2 pr-4 font-medium text-right">Output (kg)</th>
                <th className="py-2 pr-4 font-medium text-right">Rejected (kg)</th>
                <th className="py-2 pr-4 font-medium text-right">Target (kg)</th>
                <th className="py-2 font-medium text-right">Efficiency</th>
              </tr>
            </thead>
            <tbody>
              {records.slice(0, 20).map((r) => (
                <tr key={r.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-slate-300">{formatDate(r.record_date)}</td>
                  <td className="py-2 pr-4 text-white font-medium">{r.steel_grade ?? '-'}</td>
                  <td className="py-2 pr-4 text-right text-slate-300">{formatNumber(Number(r.output_weight_kg))}</td>
                  <td className="py-2 pr-4 text-right text-red-400">{formatNumber(Number(r.rejected_weight_kg))}</td>
                  <td className="py-2 pr-4 text-right text-slate-400">{r.target_weight_kg ? formatNumber(Number(r.target_weight_kg)) : '-'}</td>
                  <td className="py-2 text-right">
                    {r.target_weight_kg && Number(r.target_weight_kg) > 0
                      ? <span className="text-emerald-400">{((Number(r.output_weight_kg) / Number(r.target_weight_kg)) * 100).toFixed(0)}%</span>
                      : <span className="text-slate-600">-</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function EnergyTab({ trend, meters, deptMap }: {
  trend: EnergyTrendPoint[];
  meters: EnergyMeter[];
  deptMap: Map<string, string>;
}) {
  const totalElec = trend.reduce((s, p) => s + p.electricity, 0);
  const totalGas = trend.reduce((s, p) => s + p.gas, 0);
  const totalWater = trend.reduce((s, p) => s + p.water, 0);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Energy Intelligence</h2>
        <p className="text-slate-400 text-sm mt-1">Consumption tracking by source, department, and meter</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <KpiCard label="Electricity (30d)" value={formatNumber(totalElec)} unit="kWh" icon={<Zap className="w-5 h-5" />} accent="amber" />
        <KpiCard label="Natural Gas (30d)" value={formatNumber(totalGas)} unit="m3" icon={<Zap className="w-5 h-5" />} accent="blue" />
        <KpiCard label="Water (30d)" value={formatNumber(totalWater)} unit="m3" icon={<Zap className="w-5 h-5" />} accent="green" />
      </div>

      <ChartCard title="Energy Consumption Trends" subtitle="By source type, last 30 days">
        <ResponsiveContainer width="100%" height={320}>
          <LineChart data={trend}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
            <XAxis dataKey="date" tickFormatter={formatDate} stroke="#64748b" fontSize={11} />
            <YAxis tickFormatter={formatNumber} stroke="#64748b" fontSize={11} />
            <Tooltip
              contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', fontSize: '12px' }}
              labelStyle={{ color: '#94a3b8' }}
            />
            <Legend wrapperStyle={{ fontSize: '11px' }} />
            <Line type="monotone" dataKey="electricity" stroke={energyTypeColors.electricity} name="Electricity (kWh)" strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="gas" stroke={energyTypeColors.natural_gas} name="Gas (m3)" strokeWidth={2} dot={false} />
            <Line type="monotone" dataKey="water" stroke={energyTypeColors.water} name="Water (m3)" strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </ChartCard>

      <DataCard title="Energy Meters" subtitle={`${meters.length} active meters`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Meter Code</th>
                <th className="py-2 pr-4 font-medium">Name</th>
                <th className="py-2 pr-4 font-medium">Type</th>
                <th className="py-2 pr-4 font-medium">Department</th>
                <th className="py-2 font-medium text-right">Unit</th>
              </tr>
            </thead>
            <tbody>
              {meters.map((m) => (
                <tr key={m.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-white font-medium">{m.meter_code}</td>
                  <td className="py-2 pr-4 text-slate-300">{m.name}</td>
                  <td className="py-2 pr-4">
                    <span className="text-xs px-2 py-0.5 rounded-md" style={{ color: energyTypeColors[m.energy_type] }}>
                      {m.energy_type.replace(/_/g, ' ')}
                    </span>
                  </td>
                  <td className="py-2 pr-4 text-slate-400">{m.department_id ? deptMap.get(m.department_id) ?? '-' : '-'}</td>
                  <td className="py-2 text-right text-slate-400">{m.unit}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function EquipmentTab({ equipment, deptMap, lineMap }: {
  equipment: Equipment[];
  deptMap: Map<string, string>;
  lineMap: Map<string, string>;
}) {
  const avgHealth = equipment.length > 0 ? equipment.reduce((s, e) => s + e.health_score, 0) / equipment.length : 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Equipment Management</h2>
        <p className="text-slate-400 text-sm mt-1">Asset health, status, and operating hours</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard label="Total Units" value={String(equipment.length)} icon={<Gauge className="w-5 h-5" />} accent="blue" />
        <KpiCard label="Avg Health Score" value={avgHealth.toFixed(0)} unit="%" icon={<Activity className="w-5 h-5" />} accent="green" />
        <KpiCard label="Operational" value={String(equipment.filter((e) => e.status === 'operational').length)} icon={<Activity className="w-5 h-5" />} accent="amber" />
        <KpiCard label="Under Maintenance" value={String(equipment.filter((e) => e.status === 'under_maintenance').length)} icon={<Wrench className="w-5 h-5" />} accent="red" />
      </div>

      <DataCard title="Equipment Registry" subtitle="All monitored equipment">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Code</th>
                <th className="py-2 pr-4 font-medium">Name</th>
                <th className="py-2 pr-4 font-medium">Department</th>
                <th className="py-2 pr-4 font-medium">Line</th>
                <th className="py-2 pr-4 font-medium text-right">Health</th>
                <th className="py-2 pr-4 font-medium text-right">Hours</th>
                <th className="py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {equipment.map((eq) => (
                <tr key={eq.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-white font-medium">{eq.equipment_code}</td>
                  <td className="py-2 pr-4 text-slate-300">{eq.name}</td>
                  <td className="py-2 pr-4 text-slate-400">{eq.department_id ? deptMap.get(eq.department_id) ?? '-' : '-'}</td>
                  <td className="py-2 pr-4 text-slate-400">{eq.production_line_id ? lineMap.get(eq.production_line_id) ?? '-' : '-'}</td>
                  <td className="py-2 pr-4 text-right">
                    <span className={`font-semibold ${eq.health_score >= 80 ? 'text-emerald-400' : eq.health_score >= 60 ? 'text-amber-400' : 'text-red-400'}`}>
                      {eq.health_score}%
                    </span>
                  </td>
                  <td className="py-2 pr-4 text-right text-slate-400">{Number(eq.operating_hours).toFixed(0)}h</td>
                  <td className="py-2"><Badge text={eq.status.replace(/_/g, ' ')} className={statusColors[eq.status] ?? ''} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function MaintenanceTab({ workOrders }: { workOrders: MaintenanceWorkOrder[] }) {
  const open = workOrders.filter((w) => w.status === 'open' || w.status === 'in_progress').length;
  const overdue = workOrders.filter((w) => w.status === 'overdue').length;
  const completed = workOrders.filter((w) => w.status === 'completed').length;
  const totalCost = workOrders.reduce((s, w) => s + Number(w.cost), 0);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Maintenance Management</h2>
        <p className="text-slate-400 text-sm mt-1">Work orders, priorities, and maintenance costs</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard label="Open Work Orders" value={String(open)} icon={<Wrench className="w-5 h-5" />} accent="amber" />
        <KpiCard label="Overdue" value={String(overdue)} icon={<AlertTriangle className="w-5 h-5" />} accent="red" />
        <KpiCard label="Completed" value={String(completed)} icon={<Wrench className="w-5 h-5" />} accent="green" />
        <KpiCard label="Total Cost" value={`$${formatNumber(totalCost)}`} icon={<Wrench className="w-5 h-5" />} accent="blue" />
      </div>

      <DataCard title="Work Orders" subtitle={`${workOrders.length} total`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">WO Number</th>
                <th className="py-2 pr-4 font-medium">Type</th>
                <th className="py-2 pr-4 font-medium">Priority</th>
                <th className="py-2 pr-4 font-medium">Status</th>
                <th className="py-2 pr-4 font-medium">Description</th>
                <th className="py-2 pr-4 font-medium text-right">Cost</th>
                <th className="py-2 font-medium text-right">Downtime</th>
              </tr>
            </thead>
            <tbody>
              {workOrders.map((wo) => (
                <tr key={wo.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-white font-medium">{wo.work_order_number}</td>
                  <td className="py-2 pr-4 text-slate-400">{wo.type}</td>
                  <td className="py-2 pr-4"><Badge text={wo.priority} className={priorityColors[wo.priority] ?? ''} /></td>
                  <td className="py-2 pr-4"><Badge text={wo.status.replace(/_/g, ' ')} className="bg-slate-700/30 text-slate-400 border-slate-700" /></td>
                  <td className="py-2 pr-4 text-slate-300 max-w-xs truncate">{wo.description}</td>
                  <td className="py-2 pr-4 text-right text-slate-300">${Number(wo.cost).toLocaleString()}</td>
                  <td className="py-2 text-right text-slate-400">{Number(wo.downtime_hours)}h</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function SafetyTab({ incidents, deptMap }: {
  incidents: SafetyIncident[];
  deptMap: Map<string, string>;
}) {
  const open = incidents.filter((i) => i.status === 'reported' || i.status === 'investigating').length;
  const closed = incidents.filter((i) => i.status === 'closed' || i.status === 'resolved').length;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Safety Management</h2>
        <p className="text-slate-400 text-sm mt-1">Incident tracking, severity, and resolution status</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <KpiCard label="Open Incidents" value={String(open)} icon={<ShieldAlert className="w-5 h-5" />} accent="red" />
        <KpiCard label="Resolved/Closed" value={String(closed)} icon={<ShieldAlert className="w-5 h-5" />} accent="green" />
        <KpiCard label="Total Incidents" value={String(incidents.length)} icon={<ShieldAlert className="w-5 h-5" />} accent="blue" />
      </div>

      <DataCard title="Safety Incidents" subtitle={`${incidents.length} total incidents`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Number</th>
                <th className="py-2 pr-4 font-medium">Title</th>
                <th className="py-2 pr-4 font-medium">Severity</th>
                <th className="py-2 pr-4 font-medium">Status</th>
                <th className="py-2 pr-4 font-medium">Department</th>
                <th className="py-2 font-medium">Date</th>
              </tr>
            </thead>
            <tbody>
              {incidents.map((inc) => (
                <tr key={inc.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-white font-medium">{inc.incident_number}</td>
                  <td className="py-2 pr-4 text-slate-300 max-w-xs truncate">{inc.title}</td>
                  <td className="py-2 pr-4"><Badge text={inc.severity} className={severityColors[inc.severity] ?? ''} /></td>
                  <td className="py-2 pr-4"><Badge text={inc.status} className="bg-slate-700/30 text-slate-400 border-slate-700" /></td>
                  <td className="py-2 pr-4 text-slate-400">{inc.department_id ? deptMap.get(inc.department_id) ?? '-' : '-'}</td>
                  <td className="py-2 text-slate-400 text-xs">{formatDate(inc.incident_date)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function WarehouseTab({ items }: { items: WarehouseItem[] }) {
  const lowStock = items.filter((i) => Number(i.current_stock) <= Number(i.min_stock));
  const totalValue = items.reduce((s, i) => s + Number(i.current_stock) * Number(i.unit_cost), 0);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Warehouse & Inventory</h2>
        <p className="text-slate-400 text-sm mt-1">Stock levels, low-stock alerts, and inventory value</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard label="Total Items" value={String(items.length)} icon={<Package className="w-5 h-5" />} accent="blue" />
        <KpiCard label="Low Stock" value={String(lowStock.length)} icon={<AlertTriangle className="w-5 h-5" />} accent="red" />
        <KpiCard label="Inventory Value" value={`$${formatNumber(totalValue)}`} icon={<Package className="w-5 h-5" />} accent="green" />
        <KpiCard label="Low Stock Items" value={lowStock.map((i) => i.item_code).join(', ') || 'None'} icon={<Package className="w-5 h-5" />} accent="amber" />
      </div>

      <DataCard title="Warehouse Items" subtitle={`${items.length} items in inventory`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Code</th>
                <th className="py-2 pr-4 font-medium">Name</th>
                <th className="py-2 pr-4 font-medium text-right">Current</th>
                <th className="py-2 pr-4 font-medium text-right">Min</th>
                <th className="py-2 pr-4 font-medium text-right">Max</th>
                <th className="py-2 pr-4 font-medium text-right">Unit Cost</th>
                <th className="py-2 pr-4 font-medium text-right">Value</th>
                <th className="py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => {
                const isLow = Number(item.current_stock) <= Number(item.min_stock);
                return (
                  <tr key={item.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                    <td className="py-2 pr-4 text-white font-medium">{item.item_code}</td>
                    <td className="py-2 pr-4 text-slate-300">{item.name}</td>
                    <td className="py-2 pr-4 text-right text-slate-300">{Number(item.current_stock)} {item.unit}</td>
                    <td className="py-2 pr-4 text-right text-slate-500">{Number(item.min_stock)}</td>
                    <td className="py-2 pr-4 text-right text-slate-500">{Number(item.max_stock)}</td>
                    <td className="py-2 pr-4 text-right text-slate-400">${Number(item.unit_cost).toFixed(2)}</td>
                    <td className="py-2 pr-4 text-right text-slate-300">${(Number(item.current_stock) * Number(item.unit_cost)).toLocaleString()}</td>
                    <td className="py-2">
                      {isLow
                        ? <Badge text="Low Stock" className="bg-red-500/10 text-red-400 border-red-500/20" />
                        : <Badge text="OK" className="bg-emerald-500/10 text-emerald-400 border-emerald-500/20" />}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function ChartCard({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <div className="bg-slate-900 rounded-xl border border-slate-800 p-5">
      <div className="mb-4">
        <h3 className="text-white font-semibold text-sm">{title}</h3>
        <p className="text-slate-500 text-xs">{subtitle}</p>
      </div>
      {children}
    </div>
  );
}

function DataCard({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return (
    <div className="bg-slate-900 rounded-xl border border-slate-800 p-5">
      <div className="mb-4">
        <h3 className="text-white font-semibold text-sm">{title}</h3>
        <p className="text-slate-500 text-xs">{subtitle}</p>
      </div>
      {children}
    </div>
  );
}

const qualityResultColors: Record<string, string> = {
  pass: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20',
  fail: 'bg-red-500/10 text-red-400 border-red-500/20',
  conditional: 'bg-amber-500/10 text-amber-400 border-amber-500/20',
};

function QualityTab({ inspections, standards, stats }: {
  inspections: QualityInspection[];
  standards: QualityStandard[];
  stats: { total: number; passed: number; failed: number; conditional: number; passRate: number } | null;
}) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Quality Control</h2>
        <p className="text-slate-400 text-sm mt-1">Inspections, standards, and defect tracking</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard label="Total Inspections" value={String(stats?.total ?? 0)} icon={<ClipboardCheck className="w-5 h-5" />} accent="blue" />
        <KpiCard label="Pass Rate" value={stats ? stats.passRate.toFixed(1) : '0'} unit="%" icon={<ClipboardCheck className="w-5 h-5" />} accent="green" />
        <KpiCard label="Conditional" value={String(stats?.conditional ?? 0)} icon={<AlertTriangle className="w-5 h-5" />} accent="amber" />
        <KpiCard label="Failed" value={String(stats?.failed ?? 0)} icon={<AlertTriangle className="w-5 h-5" />} accent="red" />
      </div>

      <DataCard title="Quality Standards" subtitle={`${standards.length} active standards`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Standard</th>
                <th className="py-2 pr-4 font-medium">Grade</th>
                <th className="py-2 pr-4 font-medium">Parameter</th>
                <th className="py-2 pr-4 font-medium text-right">Min</th>
                <th className="py-2 pr-4 font-medium text-right">Max</th>
                <th className="py-2 font-medium">Unit</th>
              </tr>
            </thead>
            <tbody>
              {standards.map((s) => (
                <tr key={s.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-white font-medium">{s.name}</td>
                  <td className="py-2 pr-4 text-slate-300">{s.steel_grade}</td>
                  <td className="py-2 pr-4 text-slate-400">{s.parameter}</td>
                  <td className="py-2 pr-4 text-right text-slate-300">{s.min_value ?? '-'}</td>
                  <td className="py-2 pr-4 text-right text-slate-300">{s.max_value ?? '-'}</td>
                  <td className="py-2 text-slate-400">{s.unit}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>

      <DataCard title="Recent Inspections" subtitle={`${inspections.length} inspections`}>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-left text-slate-500 border-b border-slate-800">
                <th className="py-2 pr-4 font-medium">Number</th>
                <th className="py-2 pr-4 font-medium">Grade</th>
                <th className="py-2 pr-4 font-medium">Date</th>
                <th className="py-2 pr-4 font-medium">Result</th>
                <th className="py-2 font-medium">Notes</th>
              </tr>
            </thead>
            <tbody>
              {inspections.map((insp) => (
                <tr key={insp.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="py-2 pr-4 text-white font-medium">{insp.inspection_number}</td>
                  <td className="py-2 pr-4 text-slate-300">{insp.steel_grade ?? '-'}</td>
                  <td className="py-2 pr-4 text-slate-400 text-xs">{formatDate(insp.inspection_date)}</td>
                  <td className="py-2 pr-4"><Badge text={insp.result} className={qualityResultColors[insp.result] ?? ''} /></td>
                  <td className="py-2 text-slate-400 max-w-xs truncate text-xs">{insp.notes ?? '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </DataCard>
    </div>
  );
}

function EnvironmentTab({ readings, emissions, waste }: {
  readings: EnvironmentalReading[];
  emissions: EmissionRecord[];
  waste: WasteRecord[];
}) {
  const co2Total = emissions.filter((e) => e.emission_type === 'co2').reduce((s, e) => s + Number(e.value), 0);
  const wasteTotal = waste.reduce((s, w) => s + Number(w.quantity), 0);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white">Environmental Management</h2>
        <p className="text-slate-400 text-sm mt-1">Emissions, environmental readings, and waste tracking</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard label="CO2 Emissions (30d)" value={formatNumber(co2Total)} unit="kg" icon={<Leaf className="w-5 h-5" />} accent="green" trendLabel="Estimated" />
        <KpiCard label="Env. Readings" value={String(readings.length)} icon={<FlaskConical className="w-5 h-5" />} accent="blue" />
        <KpiCard label="Waste (30d)" value={formatNumber(wasteTotal)} unit="tonne" icon={<Leaf className="w-5 h-5" />} accent="amber" />
        <KpiCard label="Emission Records" value={String(emissions.length)} icon={<Leaf className="w-5 h-5" />} accent="purple" />
      </div>

      <ChartCard title="CO2 Emissions Trend" subtitle="Estimated daily CO2, last 30 days">
        <ResponsiveContainer width="100%" height={280}>
          <AreaChart data={emissions.filter((e) => e.emission_type === 'co2').map((e) => ({ date: e.emission_date, value: Number(e.value) })).reverse()}>
            <defs>
              <linearGradient id="co2Grad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#10b981" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
            <XAxis dataKey="date" tickFormatter={formatDate} stroke="#64748b" fontSize={11} />
            <YAxis tickFormatter={formatNumber} stroke="#64748b" fontSize={11} />
            <Tooltip
              contentStyle={{ background: '#1e293b', border: '1px solid #334155', borderRadius: '8px', fontSize: '12px' }}
              labelStyle={{ color: '#94a3b8' }}
            />
            <Area type="monotone" dataKey="value" stroke="#10b981" fill="url(#co2Grad)" name="CO2 (kg)" strokeWidth={2} />
          </AreaChart>
        </ResponsiveContainer>
      </ChartCard>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <DataCard title="Environmental Readings" subtitle={`${readings.length} readings`}>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-slate-500 border-b border-slate-800">
                  <th className="py-2 pr-4 font-medium">Type</th>
                  <th className="py-2 pr-4 font-medium">Time</th>
                  <th className="py-2 pr-4 font-medium text-right">Value</th>
                  <th className="py-2 pr-4 font-medium">Unit</th>
                  <th className="py-2 font-medium">Quality</th>
                </tr>
              </thead>
              <tbody>
                {readings.slice(0, 15).map((r) => (
                  <tr key={r.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                    <td className="py-2 pr-4 text-white font-medium">{r.reading_type.replace(/_/g, ' ')}</td>
                    <td className="py-2 pr-4 text-slate-400 text-xs">{formatDate(r.reading_time)}</td>
                    <td className="py-2 pr-4 text-right text-slate-300">{Number(r.value).toFixed(2)}</td>
                    <td className="py-2 pr-4 text-slate-400">{r.unit}</td>
                    <td className="py-2"><Badge text={r.quality} className="bg-slate-700/30 text-slate-400 border-slate-700" /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </DataCard>

        <DataCard title="Waste Records" subtitle={`${waste.length} waste entries`}>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-slate-500 border-b border-slate-800">
                  <th className="py-2 pr-4 font-medium">Type</th>
                  <th className="py-2 pr-4 font-medium">Date</th>
                  <th className="py-2 pr-4 font-medium text-right">Quantity</th>
                  <th className="py-2 font-medium">Disposal</th>
                </tr>
              </thead>
              <tbody>
                {waste.map((w) => (
                  <tr key={w.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                    <td className="py-2 pr-4 text-white font-medium">{w.waste_type}</td>
                    <td className="py-2 pr-4 text-slate-400 text-xs">{formatDate(w.waste_date)}</td>
                    <td className="py-2 pr-4 text-right text-slate-300">{Number(w.quantity).toFixed(1)} {w.unit}</td>
                    <td className="py-2 text-slate-400 text-xs">{w.disposal_method ?? '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </DataCard>
      </div>
    </div>
  );
}
