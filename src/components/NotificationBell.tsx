import { useState, useRef, useEffect } from 'react';
import { Bell, Check } from 'lucide-react';
import { useAuth } from '@/context/useAuth';
import { markNotificationRead } from '@/services/notificationService';
import type { Notification } from '@/types/database';

export function NotificationBell() {
  const { notifications, unreadNotificationCount } = useAuth();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleMarkRead = async (id: string) => {
    try {
      await markNotificationRead(id);
    } catch {
      // ignore — UI state will sync via realtime
    }
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        className="relative p-2 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/50 transition-colors"
        aria-label="Notifications"
      >
        <Bell className="w-5 h-5" />
        {unreadNotificationCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4.5 h-4.5 min-w-[18px] h-[18px] flex items-center justify-center bg-red-500 text-white text-[10px] font-bold rounded-full px-1">
            {unreadNotificationCount > 9 ? '9+' : unreadNotificationCount}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-80 bg-slate-800 border border-slate-700 rounded-xl shadow-xl z-50 max-h-96 overflow-y-auto">
          <div className="px-4 py-3 border-b border-slate-700">
            <h3 className="text-white font-semibold text-sm">Notifications</h3>
            <p className="text-slate-500 text-xs">{unreadNotificationCount} unread</p>
          </div>
          {notifications.length === 0 ? (
            <div className="px-4 py-8 text-center">
              <Bell className="w-6 h-6 text-slate-600 mx-auto mb-2" />
              <p className="text-slate-500 text-sm">No notifications</p>
            </div>
          ) : (
            <div className="divide-y divide-slate-700/50">
              {notifications.slice(0, 10).map((n: Notification) => (
                <div
                  key={n.id}
                  className={`px-4 py-3 flex items-start gap-3 hover:bg-slate-700/30 transition-colors ${!n.is_read ? 'bg-slate-700/20' : ''}`}
                >
                  <div className={`mt-1.5 w-2 h-2 rounded-full flex-shrink-0 ${n.is_read ? 'bg-slate-600' : n.severity === 'critical' ? 'bg-red-500' : n.severity === 'warning' ? 'bg-amber-500' : 'bg-blue-500'}`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-white text-sm font-medium leading-tight">{n.title}</p>
                    {n.message && <p className="text-slate-400 text-xs mt-0.5 line-clamp-2">{n.message}</p>}
                    <p className="text-slate-600 text-[10px] mt-1">{new Date(n.created_at).toLocaleString()}</p>
                  </div>
                  {!n.is_read && (
                    <button
                      onClick={() => handleMarkRead(n.id)}
                      className="text-slate-500 hover:text-emerald-400 transition-colors flex-shrink-0 mt-0.5"
                      aria-label="Mark as read"
                    >
                      <Check className="w-4 h-4" />
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
