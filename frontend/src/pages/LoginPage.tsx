import { useState } from 'react';
import type { FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { Button } from '../components/Button';
import { ApiError } from '../services/api';

export function LoginPage() {
  const { login, isAuthenticated, loading } = useAuth();
  const { error } = useToast();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [fieldErrors, setFieldErrors] = useState<{ username?: string; password?: string }>({});
  const [submitting, setSubmitting] = useState(false);

  if (!loading && isAuthenticated) {
    return <Navigate to="/" replace />;
  }

  const fillDemo = () => {
    setUsername('teacher@demo.local');
    setPassword('Demo1234!');
    setFieldErrors({});
  };

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const errors: { username?: string; password?: string } = {};
    if (!username.trim()) errors.username = 'Username or email is required.';
    if (!password) errors.password = 'Password is required.';
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) return;

    setSubmitting(true);
    try {
      await login(username.trim(), password);
      navigate('/', { replace: true });
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Sign-in failed. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-50 via-white to-slate-100 px-4">
      <div className="w-full max-w-md">
        <div className="mb-6 flex items-center justify-center gap-3">
          <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-brand-600 text-white shadow-lg" aria-hidden="true">
            <svg width="26" height="26" viewBox="0 0 20 20" fill="none">
              <rect x="2" y="4" width="16" height="12" rx="2" stroke="currentColor" strokeWidth="1.8" />
              <circle cx="10" cy="8.6" r="2.2" stroke="currentColor" strokeWidth="1.6" />
              <path d="M6 13.4c.7-1.4 2.1-2.1 4-2.1s3.3.7 4 2.1" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
            </svg>
          </span>
          <div>
            <p className="text-xl font-bold text-slate-900">ClassSnap</p>
            <p className="text-xs text-slate-500">Classroom Photo Attendance</p>
          </div>
        </div>

        <form onSubmit={onSubmit} className="card p-6 sm:p-8" noValidate aria-label="Sign in form">
          <h1 className="text-xl font-semibold text-slate-900">Sign in</h1>
          <p className="mt-1 text-sm text-slate-500">Welcome back. Enter your credentials to continue.</p>

          <div className="mt-6 space-y-4">
            <div>
              <label htmlFor="username" className="label">
                Username or email
              </label>
              <input
                id="username"
                type="text"
                autoComplete="username"
                className={`input ${fieldErrors.username ? 'border-red-400 focus:border-red-500 focus:ring-red-200' : ''}`}
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                aria-invalid={!!fieldErrors.username}
                aria-describedby={fieldErrors.username ? 'username-error' : undefined}
              />
              {fieldErrors.username && (
                <p id="username-error" role="alert" className="mt-1 text-xs text-red-600">
                  {fieldErrors.username}
                </p>
              )}
            </div>
            <div>
              <label htmlFor="password" className="label">
                Password
              </label>
              <input
                id="password"
                type="password"
                autoComplete="current-password"
                className={`input ${fieldErrors.password ? 'border-red-400 focus:border-red-500 focus:ring-red-200' : ''}`}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                aria-invalid={!!fieldErrors.password}
                aria-describedby={fieldErrors.password ? 'password-error' : undefined}
              />
              {fieldErrors.password && (
                <p id="password-error" role="alert" className="mt-1 text-xs text-red-600">
                  {fieldErrors.password}
                </p>
              )}
            </div>
          </div>

          <Button type="submit" loading={submitting} className="mt-6 w-full" size="lg">
            Sign in
          </Button>

          <div className="mt-5 rounded-lg border border-slate-200 bg-slate-50 p-3 text-xs text-slate-600">
            <p className="font-semibold text-slate-700">Demo credentials</p>
            <p className="mt-1">
              <span className="font-mono">teacher@demo.local</span> / <span className="font-mono">Demo1234!</span>
            </p>
            <button
              type="button"
              onClick={fillDemo}
              className="btn-focus mt-2 font-medium text-brand-600 hover:text-brand-700 hover:underline"
            >
              Fill demo credentials
            </button>
          </div>
        </form>

        <p className="mt-4 text-center text-xs text-slate-400">
          Attendance is teacher-confirmed: the system detects people boxes, you map them to students.
        </p>
      </div>
    </div>
  );
}
