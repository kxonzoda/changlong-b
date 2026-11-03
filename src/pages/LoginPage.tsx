import { useState, type FormEvent } from 'react';
import { Activity, Lock, Mail, Factory, ArrowLeft } from 'lucide-react';
import { signIn, signUp, resetPassword } from '@/services/authService';
import { ServiceError } from '@/services/serviceError';

export function LoginPage() {
  const [mode, setMode] = useState<'login' | 'signup' | 'reset'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setInfo(null);
    setLoading(true);
    try {
      if (mode === 'login') {
        await signIn(email, password);
      } else if (mode === 'signup') {
        await signUp(email, password, fullName || undefined);
        setInfo('Account created. Check your email if confirmation is required, then sign in.');
      } else {
        await resetPassword(email);
        setInfo('Password reset link sent. Check your email to continue.');
      }
    } catch (err) {
      if (err instanceof ServiceError) {
        setError(err.message);
      } else {
        setError('An unexpected error occurred');
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center shadow-lg shadow-orange-900/30 mb-4">
            <Factory className="w-9 h-9 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">CHANGLONG INTELLIGENCE</h1>
          <p className="text-slate-400 text-sm mt-1">Industrial Operations Platform</p>
        </div>

        <div className="bg-slate-800 rounded-2xl border border-slate-700 p-8 shadow-xl">
          {mode !== 'reset' && (
            <div className="flex gap-2 mb-6 p-1 bg-slate-900 rounded-lg">
              <button
                onClick={() => setMode('login')}
                className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${
                  mode === 'login' ? 'bg-amber-500 text-slate-900' : 'text-slate-400 hover:text-white'
                }`}
              >
                Sign In
              </button>
              <button
                onClick={() => setMode('signup')}
                className={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${
                  mode === 'signup' ? 'bg-amber-500 text-slate-900' : 'text-slate-400 hover:text-white'
                }`}
              >
                Create Account
              </button>
            </div>
          )}

          {mode === 'reset' && (
            <div className="mb-6">
              <button
                onClick={() => setMode('login')}
                className="flex items-center gap-2 text-sm text-slate-400 hover:text-white transition-colors"
              >
                <ArrowLeft className="w-4 h-4" />
                Back to sign in
              </button>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {mode === 'signup' && (
              <div>
                <label className="block text-sm text-slate-400 mb-1.5">Full Name</label>
                <input
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-4 py-2.5 text-white placeholder-slate-500 focus:border-amber-500 focus:outline-none transition-colors"
                  placeholder="Zhang Wei"
                />
              </div>
            )}
            <div>
              <label className="block text-sm text-slate-400 mb-1.5">Email</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-10 pr-4 py-2.5 text-white placeholder-slate-500 focus:border-amber-500 focus:outline-none transition-colors"
                  placeholder="you@changlong.com"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm text-slate-400 mb-1.5">Password</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-10 pr-4 py-2.5 text-white placeholder-slate-500 focus:border-amber-500 focus:outline-none transition-colors"
                  placeholder="••••••••"
                  minLength={6}
                />
              </div>
            </div>

            {error && (
              <div className="text-sm text-red-400 bg-red-950/40 border border-red-800/50 rounded-lg px-4 py-3">
                {error}
              </div>
            )}

            {info && (
              <div className="text-sm text-emerald-400 bg-emerald-950/40 border border-emerald-800/50 rounded-lg px-4 py-3">
                {info}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-amber-500 hover:bg-amber-400 disabled:opacity-50 text-slate-900 font-semibold rounded-lg py-2.5 transition-colors flex items-center justify-center gap-2"
            >
              {loading ? (
                <Activity className="w-4 h-4 animate-pulse" />
              ) : mode === 'login' ? (
                'Sign In'
              ) : mode === 'signup' ? (
                'Create Account'
              ) : (
                'Send Reset Link'
              )}
            </button>
          </form>

          {mode === 'login' && (
            <button
              onClick={() => { setMode('reset'); setError(null); setInfo(null); }}
              className="w-full text-sm text-slate-400 hover:text-amber-400 transition-colors mt-4 text-center"
            >
              Forgot password?
            </button>
          )}

          {mode !== 'reset' && (
            <p className="text-xs text-slate-500 text-center mt-6">
              New accounts are assigned the viewer role by default.
              Contact an administrator to change your access level.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
