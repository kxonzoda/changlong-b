import { useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import type { Profile, Notification } from '@/types/database';
import { getCurrentProfile } from '@/services/authService';
import { getNotifications } from '@/services/notificationService';
import { AuthContext } from './authContext';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  const [notifications, setNotifications] = useState<Notification[]>([]);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (data.session) {
        (async () => {
          const p = await getCurrentProfile();
          setProfile(p);
          if (p) {
            const notifs = await getNotifications().catch(() => []);
            setNotifications(notifs);
          }
          setLoading(false);
        })();
      } else {
        setLoading(false);
      }
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      if (newSession) {
        (async () => {
          const p = await getCurrentProfile();
          setProfile(p);
          if (p) {
            const notifs = await getNotifications().catch(() => []);
            setNotifications(notifs);
          }
          setLoading(false);
        })();
      } else {
        setProfile(null);
        setNotifications([]);
        setLoading(false);
      }
    });

    return () => listener.subscription.unsubscribe();
  }, []);

  // Realtime subscription for notifications
  useEffect(() => {
    if (!profile) return;

    const channel = supabase
      .channel('notifications-realtime')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${profile.id}`,
        },
        (payload) => {
          setNotifications((prev) => [payload.new as Notification, ...prev]);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${profile.id}`,
        },
        (payload) => {
          const updated = payload.new as Notification;
          setNotifications((prev) =>
            prev.map((n) => (n.id === updated.id ? updated : n))
          );
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [profile]);

  const unreadCount = notifications.filter((n) => !n.is_read).length;

  return (
    <AuthContext.Provider value={{ session, profile, loading, notifications, unreadNotificationCount: unreadCount }}>
      {children}
    </AuthContext.Provider>
  );
}
