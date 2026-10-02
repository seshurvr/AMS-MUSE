import { useState } from 'react';
import type { FormEvent } from 'react';
import { Layout } from '../components/Layout';
import { Button } from '../components/Button';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { authApi, ApiError } from '../services/api';

export function SettingsPage() {
  const { user, refresh } = useAuth();
  const { success, error } = useToast();
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const errs: Record<string, string> = {};
    if (!current) errs.current = 'Enter your current password.';
    if (next.length < 8) errs.next = 'New password must be at least 8 characters.';
    if (confirm !== next) errs.confirm = 'Passwords do not match.';
    setFieldErrors(errs);
    if (Object.keys(errs).length > 0) return;

    setSaving(true);
    try {
      await authApi.changePassword(current, next);
      setCurrent('');
      setNext('');
      setConfirm('');
      success('Password changed successfully.');
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to change password.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Layout title="Settings">
      <div className="grid gap-4 lg:grid-cols-2">
        <div className="card p-6">
          <h2 className="text-base font-semibold text-slate-900">Profile</h2>
          <dl className="mt-4 space-y-3 text-sm">
            <div>
              <dt className="text-xs text-slate-500">Username</dt>
              <dd className="font-medium text-slate-900">{user?.username}</dd>
            </div>
            <div>
              <dt className="text-xs text-slate-500">Email</dt>
              <dd className="font-medium text-slate-900">{user?.email}</dd>
            </div>
            <div>
              <dt className="text-xs text-slate-500">Role</dt>
              <dd className="font-medium capitalize text-slate-900">{user?.role}</dd>
            </div>
          </dl>
          <Button variant="secondary" size="sm" className="mt-4" onClick={() => void refresh()}>
            Refresh profile
          </Button>
        </div>

        <div className="card p-6">
          <h2 className="text-base font-semibold text-slate-900">Change password</h2>
          <form onSubmit={onSubmit} className="mt-4 space-y-4" noValidate aria-label="Change password form">
            <div>
              <label htmlFor="pw-current" className="label">Current password</label>
              <input
                id="pw-current"
                type="password"
                autoComplete="current-password"
                className="input"
                value={current}
                onChange={(e) => setCurrent(e.target.value)}
                aria-invalid={!!fieldErrors.current}
              />
              {fieldErrors.current && <p role="alert" className="mt-1 text-xs text-red-600">{fieldErrors.current}</p>}
            </div>
            <div>
              <label htmlFor="pw-new" className="label">New password</label>
              <input
                id="pw-new"
                type="password"
                autoComplete="new-password"
                className="input"
                value={next}
                onChange={(e) => setNext(e.target.value)}
                aria-invalid={!!fieldErrors.next}
                aria-describedby="pw-new-hint"
              />
              <p id="pw-new-hint" className="mt-1 text-xs text-slate-500">At least 8 characters.</p>
              {fieldErrors.next && <p role="alert" className="mt-1 text-xs text-red-600">{fieldErrors.next}</p>}
            </div>
            <div>
              <label htmlFor="pw-confirm" className="label">Confirm new password</label>
              <input
                id="pw-confirm"
                type="password"
                autoComplete="new-password"
                className="input"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                aria-invalid={!!fieldErrors.confirm}
              />
              {fieldErrors.confirm && <p role="alert" className="mt-1 text-xs text-red-600">{fieldErrors.confirm}</p>}
            </div>
            <Button type="submit" loading={saving}>Change password</Button>
          </form>
        </div>
      </div>

      <div className="card mt-4 p-6">
        <h2 className="text-base font-semibold text-slate-900">About</h2>
        <dl className="mt-3 grid gap-3 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-xs text-slate-500">Application</dt>
            <dd className="font-medium text-slate-900">ClassSnap — Classroom Photo Attendance Management System</dd>
          </div>
          <div>
            <dt className="text-xs text-slate-500">Version</dt>
            <dd className="font-medium text-slate-900">1.0.0</dd>
          </div>
          <div className="sm:col-span-2">
            <dt className="text-xs text-slate-500">How it works</dt>
            <dd className="mt-1 text-slate-600">
              Upload a classroom photo for each session. The system detects people and draws a box around each one —
              it never identifies faces. The teacher manually maps every box to a student and confirms each mapping.
              Only teacher-confirmed mappings count toward attendance.
            </dd>
          </div>
        </dl>
      </div>
    </Layout>
  );
}
