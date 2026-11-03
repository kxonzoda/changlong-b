import { createContext } from 'react';
import type { Session } from '@supabase/supabase-js';
import type { Profile, Notification } from '@/types/database';

export interface AuthContextValue {
  session: Session | null;
  profile: Profile | null;
  loading: boolean;
  notifications: Notification[];
  unreadNotificationCount: number;
}

export const AuthContext = createContext<AuthContextValue>({
  session: null,
  profile: null,
  loading: true,
  notifications: [],
  unreadNotificationCount: 0,
});
