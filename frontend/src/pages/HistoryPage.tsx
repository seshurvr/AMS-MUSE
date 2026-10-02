import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { DataTable } from '../components/DataTable';
import { Modal } from '../components/Modal';
import { Button } from '../components/Button';
import { AttendanceStatusBadge } from '../components/AttendanceStatusBadge';
import { useToast } from '../context/ToastContext';
import { classesApi, attendanceApi, reportsApi, ApiError } from '../services/api';
import type { ClassItem, HistoryItem } from '../services/api';

function monthAgoISO(): string {
  const d = new Date();
  d.setDate(d.getDate() - 30);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function HistoryPage() {
  const { success, error } = useToast();
  const navigate = useNavigate();
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [rows, setRows] = useState<HistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [classId, setClassId] = useState<number | ''>('');
  const [from, setFrom] = useState(monthAgoISO());
  const [to, setTo] = useState(todayISO());
  const [subject, setSubject] = useState('');

  const [deleteTarget, setDeleteTarget] = useState<HistoryItem | null>(null);
  const [exportTarget, setExportTarget] = useState<HistoryItem | null>(null);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    void (async () => {
      try {
        const cls = await classesApi.list();
        setClasses(cls);
      } catch (err) {
        error(err instanceof ApiError ? err.message : 'Failed to load classes.');
      }
    })();
  }, [error]);

  const load = async () => {
    setLoading(true);
    setLoadError(null);
    try {
      let data = await attendanceApi.history({
        class_id: classId,
        from: from || undefined,
        to: to || undefined,
      });
      if (subject.trim()) {
        const q = subject.trim().toLowerCase();
        data = data.filter((h) => h.subject.toLowerCase().includes(q));
      }
      setRows(data);
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to load history.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [classId, from, to]);

  const onSearch = () => void load();

  const onDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await attendanceApi.deleteSession(deleteTarget.id);
      success('Session deleted.');
      setDeleteTarget(null);
      await load();
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to delete session.');
    } finally {
      setDeleting(false);
    }
  };

  const onExport = async (format: 'csv' | 'xlsx') => {
    if (!exportTarget) return;
    try {
      await reportsApi.exportAttendance(exportTarget.id, format);
      success(`Session exported as ${format.toUpperCase()}.`);
      setExportTarget(null);
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Export failed.');
    }
  };

  return (
    <Layout title="Attendance History">
      <div className="card mb-4 p-4">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <div>
            <label htmlFor="hist-class" className="label">Class</label>
            <select id="hist-class" className="input" value={classId} onChange={(e) => setClassId(e.target.value ? Number(e.target.value) : '')}>
              <option value="">All classes</option>
              {classes.map((c) => (
                <option key={c.id} value={c.id}>{c.name} ({c.section})</option>
              ))}
            </select>
          </div>
          <div>
            <label htmlFor="hist-from" className="label">From</label>
            <input id="hist-from" type="date" className="input" value={from} onChange={(e) => setFrom(e.target.value)} />
          </div>
          <div>
            <label htmlFor="hist-to" className="label">To</label>
            <input id="hist-to" type="date" className="input" value={to} onChange={(e) => setTo(e.target.value)} />
          </div>
          <div>
            <label htmlFor="hist-subject" className="label">Subject</label>
            <input id="hist-subject" className="input" value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="Filter by subject…" />
          </div>
          <div className="flex items-end">
            <Button onClick={onSearch} className="w-full">Apply filters</Button>
          </div>
        </div>
      </div>

      {loading ? (
        <LoadingSpinner label="Loading history…" />
      ) : loadError ? (
        <ErrorAlert message={loadError} onRetry={load} />
      ) : (
        <DataTable<HistoryItem>
          ariaLabel="Attendance history"
          columns={[
            { key: 'date', header: 'Date', render: (r) => r.date },
            { key: 'time', header: 'Time', render: (r) => r.session_time },
            { key: 'class', header: 'Class', render: (r) => `${r.class_name} (${r.section})` },
            { key: 'subject', header: 'Subject', render: (r) => r.subject },
            {
              key: 'counts',
              header: 'P / A / E',
              render: (r) => (
                <span className="tabular-nums text-sm">
                  <span className="text-emerald-700">{r.present}</span> / <span className="text-red-700">{r.absent}</span> / <span className="text-sky-700">{r.excused}</span>
                  <span className="text-slate-400"> of {r.total}</span>
                </span>
              ),
            },
            {
              key: 'review',
              header: 'Needs review',
              render: (r) => (r.needs_review > 0 ? <AttendanceStatusBadge status="needs_review" size="sm" /> : <span className="text-slate-400">—</span>),
            },
            {
              key: 'status',
              header: 'Status',
              render: (r) =>
                r.status === 'finalized' ? (
                  <span className="inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-700 ring-1 ring-inset ring-slate-600/10">Finalized</span>
                ) : (
                  <span className="inline-flex rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-900 ring-1 ring-inset ring-amber-600/20">Draft</span>
                ),
            },
            {
              key: 'actions',
              header: 'Actions',
              render: (r) => (
                <span className="flex flex-wrap gap-1.5">
                  <Button size="sm" variant="secondary" onClick={() => navigate(`/attendance/${r.id}`)}>View</Button>
                  {r.status !== 'finalized' && (
                    <Button size="sm" variant="secondary" onClick={() => navigate(`/attendance/${r.id}/review`)}>Edit</Button>
                  )}
                  <Button size="sm" variant="secondary" onClick={() => setExportTarget(r)}>Export</Button>
                  <Button size="sm" variant="ghost" className="text-red-700" onClick={() => setDeleteTarget(r)}>Delete</Button>
                </span>
              ),
            },
          ]}
          rows={rows}
          rowKey={(r) => r.id}
          emptyMessage="No sessions match these filters."
        />
      )}

      <Modal
        open={deleteTarget !== null}
        title="Delete session"
        onClose={() => setDeleteTarget(null)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleteTarget(null)}>Cancel</Button>
            <Button variant="danger" loading={deleting} onClick={onDelete}>Delete session</Button>
          </>
        }
      >
        <p className="text-sm text-slate-600">
          Delete the session <strong>{deleteTarget?.class_name}</strong> on <strong>{deleteTarget?.date}</strong> at{' '}
          <strong>{deleteTarget?.session_time}</strong>? This permanently removes its photo, detections and attendance records.
        </p>
      </Modal>

      <Modal
        open={exportTarget !== null}
        title="Export session"
        onClose={() => setExportTarget(null)}
        footer={
          <Button variant="secondary" onClick={() => setExportTarget(null)}>Cancel</Button>
        }
      >
        <p className="text-sm text-slate-600">Choose a format for the attendance records of this session.</p>
        <div className="mt-4 flex gap-2">
          <Button variant="secondary" onClick={() => onExport('csv')}>Download CSV</Button>
          <Button variant="secondary" onClick={() => onExport('xlsx')}>Download Excel</Button>
        </div>
      </Modal>
    </Layout>
  );
}
