import { useState } from 'react';
import { AuthProvider } from '@/context/AuthContext';
import { useAuth } from '@/context/useAuth';
import { LoginPage } from '@/pages/LoginPage';
import { DashboardPage } from '@/pages/DashboardPage';
import { Sidebar, type DashboardTab } from '@/components/Sidebar';
import { signOut } from '@/services/authService';

function AppContent() {
  const { session, profile, loading } = useAuth();
  const [activeTab, setActiveTab] = useState<DashboardTab>('overview');

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <div className="text-slate-500 text-sm">Loading...</div>
      </div>
    );
  }

  if (!session) {
    return <LoginPage />;
  }

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch {
      // error already surfaced via auth state
    }
  };

  return (
    <div className="flex bg-slate-950 min-h-screen">
      <Sidebar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        role={profile?.role ?? null}
        fullName={profile?.full_name ?? null}
        onSignOut={handleSignOut}
      />
      <DashboardPage tab={activeTab} />
    </div>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
