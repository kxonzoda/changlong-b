import { Factory, LayoutDashboard, Zap, Wrench, ShieldAlert, Package, LogOut, Settings, ClipboardCheck, Leaf } from 'lucide-react';
import { NotificationBell } from '@/components/NotificationBell';
import type { UserRole } from '@/types/database';

export type DashboardTab = 'overview' | 'production' | 'energy' | 'equipment' | 'maintenance' | 'quality' | 'safety' | 'warehouse' | 'environment';

interface SidebarProps {
  activeTab: DashboardTab;
  onTabChange: (tab: DashboardTab) => void;
  role: UserRole | null;
  fullName: string | null;
  onSignOut: () => void;
}

const navItems: { id: DashboardTab; label: string; icon: typeof LayoutDashboard }[] = [
  { id: 'overview', label: 'Overview', icon: LayoutDashboard },
  { id: 'production', label: 'Production', icon: Factory },
  { id: 'energy', label: 'Energy', icon: Zap },
  { id: 'equipment', label: 'Equipment', icon: Settings },
  { id: 'maintenance', label: 'Maintenance', icon: Wrench },
  { id: 'quality', label: 'Quality', icon: ClipboardCheck },
  { id: 'safety', label: 'Safety', icon: ShieldAlert },
  { id: 'warehouse', label: 'Warehouse', icon: Package },
  { id: 'environment', label: 'Environment', icon: Leaf },
];

const roleLabels: Record<UserRole, string> = {
  admin: 'Administrator',
  plant_director: 'Plant Director',
  manager: 'Manager',
  production_manager: 'Production Manager',
  engineer: 'Engineer',
  energy_manager: 'Energy Manager',
  maintenance_manager: 'Maintenance Manager',
  safety_officer: 'Safety Officer',
  warehouse_manager: 'Warehouse Manager',
  operator: 'Operator',
  viewer: 'Viewer',
};

export function Sidebar({ activeTab, onTabChange, role, fullName, onSignOut }: SidebarProps) {
  return (
    <aside className="w-64 bg-slate-900 border-r border-slate-800 flex flex-col h-screen sticky top-0">
      <div className="px-6 py-5 border-b border-slate-800">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center shadow-lg shadow-orange-900/30">
            <Factory className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-white font-bold text-sm leading-tight">CHANGLONG</h1>
            <p className="text-slate-500 text-xs">INTELLIGENCE</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {navItems.map((item) => {
          const Icon = item.icon;
          const active = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onTabChange(item.id)}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                active
                  ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/50 border border-transparent'
              }`}
            >
              <Icon className="w-4 h-4 flex-shrink-0" />
              {item.label}
            </button>
          );
        })}
      </nav>

      <div className="px-3 py-4 border-t border-slate-800">
        <div className="px-3 py-2 mb-2 flex items-center justify-between">
          <div className="min-w-0">
            <p className="text-white text-sm font-medium truncate">{fullName ?? 'User'}</p>
            <p className="text-slate-500 text-xs">{role ? roleLabels[role] : ''}</p>
          </div>
          <NotificationBell />
        </div>
        <button
          onClick={onSignOut}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-slate-400 hover:text-red-400 hover:bg-slate-800/50 transition-colors"
        >
          <LogOut className="w-4 h-4" />
          Sign Out
        </button>
      </div>
    </aside>
  );
}
