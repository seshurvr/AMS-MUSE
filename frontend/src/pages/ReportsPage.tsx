import { useEffect, useState } from 'react';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { DataTable } from '../components/DataTable';
import { Button } from '../components/Button';
import { useToast } from '../context/ToastContext';
import { classesApi, reportsApi, ApiError } from '../services/api';
import type { ClassItem, ReportStudentRow } from '../services/api';

function monthAgoISO(): string {
  const d = new Date();
  d.setDate(d.getDate() - 30);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function ReportsPage() {
  const { error } = useToast();
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [rows, setRows] = useState<ReportStudentRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [hasRun, setHasRun] = useState(false);

  const [classId, setClassId] = useState<number | ''>('');
  const [from, setFrom] = useState(monthAgoISO());
  const [to, setTo] = useState(todayISO());

  useEffect(() => {
    void (async () => {
      try {
        const cls = await classesApi.list();
        const active = cls.filter((c) => c.status !== 'archived');
        setClasses(active);
        if (active.length > 0) setClassId(active[0].id);
      } catch (err) {
        error(err instanceof ApiError ? err.message : 'Failed to load classes.');
      }
    })();
  }, [error]);

  const run = async () => {
    if (!classId) {
      error('Select a class to generate a report.');
      return;
    }
    setLoading(true);
    setLoadError(null);
    try {
      const res = await reportsApi.summary({ class_id: classId, from: from || undefined, to: to || undefined });
      setRows(res.students);
      setHasRun(true);
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to generate report.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (classId) void run();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [classId]);

  const totals = rows.reduce(
    (acc, r) => ({
      sessions: Math.max(acc.sessions, r.total_sessions),
      present: acc.present + r.present,
      absent: acc.absent + r.absent,
      excused: acc.excused + r.excused,
      needs_review: acc.needs_review + r.needs_review,
    }),
    { sessions: 0, present: 0, absent: 0, excused: 0, needs_review: 0 },
  );
  const eligible = totals.present + totals.absent;
  const classPct = eligible > 0 ? (totals.present / eligible) * 100 : 0;

  return (
    <Layout title="Reports">
      <div className="card mb-4 p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <label htmlFor="rep-class" className="label">Class</label>
            <select id="rep-class" className="input" value={classId} onChange={(e) => setClassId(e.target.value ? Number(e.target.value) : '')}>
              <option value="">Select a class…</option>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>{c.name} ({c.section})</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="rep-from" className="label">From</label>
            <input id="rep-from" type="date" className="input" value={from} onChange={(e) => setFrom(e.target.value)} />
          </div>
          <div>
            <label htmlFor="rep-to" className="label">To</label>
            <input id="rep-to" type="date" className="input" value={to} onChange={(e) => setTo(e.target.value)} />
          </div>
          <div className="flex items-end">
            <Button onClick={run} loading={loading} className="w-full">Generate report</Button>
          </div>
        </div>
      </div>

      {loading ? (
        <LoadingSpinner label="Generating report…" />
      ) : loadError ? (
        <ErrorAlert message={loadError} onRetry={run} />
      ) : hasRun ? (
        <>
          <div className="card mb-4 grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-5">
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Sessions in range</p>
              <p className="mt-1 text-2xl font-bold tabular-nums text-slate-900">{totals.sessions}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Total present</p>
              <p className="mt-1 text-2xl font-bold tabular-nums text-emerald-700">{totals.present}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Total absent</p>
              <p className="mt-1 text-2xl font-bold tabular-nums text-red-700">{totals.absent}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Total excused</p>
              <p className="mt-1 text-2xl font-bold tabular-nums text-sky-700">{totals.excused}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Class attendance</p>
              <p className="mt-1 text-2xl font-bold tabular-nums text-slate-900">{Math.round(classPct)}%</p>
            </div>
          </div>

          <DataTable<ReportStudentRow>
            ariaLabel="Per-student attendance report"
            columns={[
              { key: 'roll', header: 'Roll no.', render: (r) => r.roll_number },
              { key: 'name', header: 'Name', render: (r) => <span className="font-medium">{r.name}</span> },
              { key: 'sessions', header: 'Sessions', render: (r) => <span className="tabular-nums">{r.total_sessions}</span> },
              { key: 'present', header: 'Present', render: (r) => <span className="tabular-nums text-emerald-700">{r.present}</span> },
              { key: 'absent', header: 'Absent', render: (r) => <span className="tabular-nums text-red-700">{r.absent}</span> },
              { key: 'excused', header: 'Excused', render: (r) => <span className="tabular-nums text-sky-700">{r.excused}</span> },
              { key: 'review', header: 'Needs review', render: (r) => <span className="tabular-nums text-amber-700">{r.needs_review}</span> },
              {
                key: 'pct',
                header: 'Attendance %',
                render: (r) => (
                  <span className="flex items-center gap-2">
                    <span className="w-24 overflow-hidden rounded-full bg-slate-100" aria-hidden="true">
                      <span className="block h-2 rounded-full bg-brand-600" style={{ width: `${Math.round(r.attendance_percentage)}%` }} />
                    </span>
                    <span className="font-semibold tabular-nums">{Math.round(r.attendance_percentage)}%</span>
                  </span>
                ),
              },
            ]}
            rows={rows}
            rowKey={(r) => r.student_id}
            emptyMessage="No attendance data for this class and date range."
          />

          <div className="card mt-4 p-4 text-sm text-slate-600" role="note" aria-label="How attendance percentage is calculated">
            <p className="font-semibold text-slate-800">How the percentage is calculated</p>
            <p className="mt-1">
              Attendance % = <span className="font-mono">present ÷ (present + absent) × 100</span>.
              Excused sessions are excluded from the calculation (they count as neither present nor absent).
              Records marked <em>Needs review</em> are also excluded — they are not counted as absent until you confirm them.
            </p>
          </div>
        </>
      ) : (
        <div className="card p-10 text-center text-sm text-slate-500">
          Select a class and date range, then generate the report.
        </div>
      )}
    </Layout>
  );
}
