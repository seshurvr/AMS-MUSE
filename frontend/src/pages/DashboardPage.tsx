import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { DataTable } from '../components/DataTable';
import { AttendanceStatusBadge } from '../components/AttendanceStatusBadge';
import { Button } from '../components/Button';
import { useToast } from '../context/ToastContext';
import { classesApi, attendanceApi, ApiError } from '../services/api';
import type { ClassItem, HistoryItem } from '../services/api';

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function DashboardPage() {
  const { error } = useToast();
  const navigate = useNavigate();
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const [cls, hist] = await Promise.all([
        classesApi.list(),
        attendanceApi.history({ from: todayISO(), to: todayISO() }).catch(() => [] as HistoryItem[]),
      ]);
      setClasses(cls);
      setHistory(hist);
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to load dashboard data.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const stats = useMemo(() => {
    const totalStudents = classes.reduce((sum, c) => sum + (c.student_count ?? 0), 0);
    const todaysSessions = history.length;
    const needsReview = history.reduce((sum, h) => sum + (h.needs_review ?? 0), 0);
    const eligible = history.reduce((sum, h) => sum + (h.present ?? 0) + (h.absent ?? 0), 0);
    const present = history.reduce((sum, h) => sum + (h.present ?? 0), 0);
    const avg = eligible > 0 ? (present / eligible) * 100 : 0;
    return { totalClasses: classes.length, totalStudents, todaysSessions, avg, needsReview };
  }, [classes, history]);

  const recent = useMemo(() => history.slice(0, 5), [history]);

  const cards = [
    { label: 'Total classes', value: String(stats.totalClasses), icon: 'M2.5 6.5L9 3l6.5 3.5L9 10 2.5 6.5z' },
    { label: 'Total students', value: String(stats.totalStudents), icon: 'M6.5 3a3 3 0 100 6 3 3 0 000-6zM1.5 15.5c.7-2.6 2.7-4 5-4s4.3 1.4 5 4' },
    { label: "Today's sessions", value: String(stats.todaysSessions), icon: 'M3 3h12v12H3zM6 1.5v3M12 1.5v3' },
    { label: 'Avg attendance today', value: `${Math.round(stats.avg)}%`, icon: 'M3 15.5V9.5M8 15.5v-9M13 15.5V4.5' },
    { label: 'Needs review', value: String(stats.needsReview), icon: 'M9 3l7 10H2L9 3zM9 7v2.5M9 12v.1' },
  ];

  return (
    <Layout title="Dashboard">
      {loading ? (
        <LoadingSpinner label="Loading dashboard…" />
      ) : loadError ? (
        <ErrorAlert message={loadError} onRetry={load} />
      ) : (
        <>
          <div className="grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-5">
            {cards.map((c) => (
              <div key={c.label} className="card flex items-center gap-3 p-4">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600" aria-hidden="true">
                  <svg width="20" height="20" viewBox="0 0 18 18" fill="none">
                    <path d={c.icon} stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </span>
                <div className="min-w-0">
                  <p className="truncate text-xs font-medium text-slate-500">{c.label}</p>
                  <p className="text-2xl font-bold text-slate-900">{c.value}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <button type="button" onClick={() => navigate('/classes')} className="btn-focus card group p-4 text-left hover:border-brand-300 hover:shadow">
              <p className="font-semibold text-slate-900 group-hover:text-brand-700">New class</p>
              <p className="mt-1 text-sm text-slate-500">Create a class and add its students.</p>
            </button>
            <button type="button" onClick={() => navigate('/students')} className="btn-focus card group p-4 text-left hover:border-brand-300 hover:shadow">
              <p className="font-semibold text-slate-900 group-hover:text-brand-700">Manage students</p>
              <p className="mt-1 text-sm text-slate-500">Add, edit, import or export student rosters.</p>
            </button>
            <button type="button" onClick={() => navigate('/attendance/new')} className="btn-focus card group p-4 text-left hover:border-brand-300 hover:shadow">
              <p className="font-semibold text-slate-900 group-hover:text-brand-700">Take attendance</p>
              <p className="mt-1 text-sm text-slate-500">Start a session with a classroom photo.</p>
            </button>
            <button type="button" onClick={() => navigate('/attendance/history')} className="btn-focus card group p-4 text-left hover:border-brand-300 hover:shadow">
              <p className="font-semibold text-slate-900 group-hover:text-brand-700">View history</p>
              <p className="mt-1 text-sm text-slate-500">Browse, edit and export past sessions.</p>
            </button>
          </div>

          <div className="mt-8">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-base font-semibold text-slate-900">Recent sessions</h2>
              <Link to="/attendance/history" className="btn-focus text-sm font-medium text-brand-600 hover:text-brand-700 hover:underline">
                View all
              </Link>
            </div>
            <DataTable<HistoryItem>
              ariaLabel="Recent attendance sessions"
              columns={[
                { key: 'date', header: 'Date', render: (r) => `${r.date} · ${r.session_time}` },
                { key: 'class', header: 'Class', render: (r) => `${r.class_name} (${r.section})` },
                { key: 'subject', header: 'Subject', render: (r) => r.subject },
                {
                  key: 'attendance',
                  header: 'Attendance',
                  render: (r) => (
                    <span className="tabular-nums">
                      {r.present}/{r.total}
                    </span>
                  ),
                },
                {
                  key: 'status',
                  header: 'Status',
                  render: (r) =>
                    r.status === 'finalized' ? (
                      <span className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700 ring-1 ring-inset ring-slate-600/10">
                        Finalized
                      </span>
                    ) : (
                      <span className="inline-flex items-center rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-900 ring-1 ring-inset ring-amber-600/20">
                        Draft
                      </span>
                    ),
                },
                {
                  key: 'review',
                  header: 'Review',
                  render: (r) =>
                    r.needs_review > 0 ? <AttendanceStatusBadge status="needs_review" size="sm" /> : <span className="text-slate-400">—</span>,
                },
                {
                  key: 'actions',
                  header: 'Actions',
                  render: (r) => (
                    <Button size="sm" variant="secondary" onClick={() => navigate(`/attendance/${r.id}`)}>
                      View
                    </Button>
                  ),
                },
              ]}
              rows={recent}
              rowKey={(r) => r.id}
              emptyMessage="No sessions yet today. Start one with “Take Attendance”."
            />
          </div>
        </>
      )}
    </Layout>
  );
}
