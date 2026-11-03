import type { ReactNode } from 'react';
import { TrendingUp, TrendingDown } from 'lucide-react';

interface KpiCardProps {
  label: string;
  value: string;
  unit?: string;
  icon: ReactNode;
  trend?: number;
  trendLabel?: string;
  accent: 'amber' | 'blue' | 'green' | 'red' | 'purple';
}

const accentStyles = {
  amber: { bg: 'bg-amber-500/10', text: 'text-amber-400', border: 'border-amber-500/20' },
  blue: { bg: 'bg-blue-500/10', text: 'text-blue-400', border: 'border-blue-500/20' },
  green: { bg: 'bg-emerald-500/10', text: 'text-emerald-400', border: 'border-emerald-500/20' },
  red: { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/20' },
  purple: { bg: 'bg-purple-500/10', text: 'text-purple-400', border: 'border-purple-500/20' },
};

export function KpiCard({ label, value, unit, icon, trend, trendLabel, accent }: KpiCardProps) {
  const s = accentStyles[accent];
  return (
    <div className={`bg-slate-800/50 rounded-xl border ${s.border} p-5 hover:bg-slate-800 transition-colors`}>
      <div className="flex items-start justify-between mb-3">
        <div className={`w-10 h-10 rounded-lg ${s.bg} flex items-center justify-center`}>
          <div className={s.text}>{icon}</div>
        </div>
        {trend !== undefined && (
          <div className={`flex items-center gap-1 text-xs ${trend >= 0 ? 'text-emerald-400' : 'text-red-400'}`}>
            {trend >= 0 ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
            {Math.abs(trend).toFixed(1)}%
          </div>
        )}
      </div>
      <p className="text-slate-400 text-xs font-medium uppercase tracking-wider">{label}</p>
      <div className="flex items-baseline gap-1 mt-1">
        <span className="text-2xl font-bold text-white">{value}</span>
        {unit && <span className="text-sm text-slate-500">{unit}</span>}
      </div>
      {trendLabel && <p className="text-xs text-slate-500 mt-1">{trendLabel}</p>}
    </div>
  );
}
