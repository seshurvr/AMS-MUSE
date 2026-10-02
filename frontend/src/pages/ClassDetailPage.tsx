import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { DataTable } from '../components/DataTable';
import { Button } from '../components/Button';
import { useToast } from '../context/ToastContext';
import { classesApi, ApiError } from '../services/api';
import type { ClassDetail } from '../services/api';

export function ClassDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { error } = useToast();
  const [detail, setDetail] = useState<ClassDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const load = async () => {
    if (!id) return;
    setLoading(true);
    setLoadError(null);
    try {
      setDetail(await classesApi.get(Number(id)));
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to load class.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, [id]);

  return (
    <Layout title={detail ? `${detail.name} (${detail.section})` : 'Class detail'}>
      <div className="mb-4">
        <Link to="/classes" className="btn-focus text-sm font-medium text-brand-600 hover:underline">
          ← Back to classes
        </Link>
      </div>

      {loading ? (
        <LoadingSpinner label="Loading class…" />
      ) : loadError || !detail ? (
        <ErrorAlert message={loadError ?? 'Class not found.'} onRetry={load} />
      ) : (
        <>
          <div className="card grid gap-4 p-5 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Subject</p>
              <p className="mt-1 font-medium text-slate-900">{detail.subject}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Academic year</p>
              <p className="mt-1 font-medium text-slate-900">{detail.academic_year}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Students</p>
              <p className="mt-1 font-medium text-slate-900 tabular-nums">{detail.students.length}</p>
            </div>
            <div>
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Status</p>
              <p className="mt-1 font-medium text-slate-900 capitalize">{detail.status}</p>
            </div>
          </div>

          <div className="mb-3 mt-8 flex items-center justify-between">
            <h2 className="text-base font-semibold text-slate-900">Students</h2>
            <Button size="sm" variant="secondary" onClick={() => navigate('/students')}>
              Manage students
            </Button>
          </div>

          <DataTable
            ariaLabel="Students in class"
            columns={[
              { key: 'roll', header: 'Roll no.', render: (r) => r.roll_number },
              { key: 'name', header: 'Name', render: (r) => <span className="font-medium">{r.name}</span> },
              { key: 'sid', header: 'Student ID', render: (r) => <span className="font-mono text-xs">{r.student_id}</span> },
              { key: 'email', header: 'Email', render: (r) => r.email ?? <span className="text-slate-400">—</span> },
              {
                key: 'status',
                header: 'Status',
                render: (r) => (
                  <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-medium ring-1 ring-inset ${
                    r.status === 'archived'
                      ? 'bg-slate-100 text-slate-600 ring-slate-600/10'
                      : 'bg-emerald-100 text-emerald-800 ring-emerald-600/20'
                  }`}>
                    {r.status === 'archived' ? 'Archived' : 'Active'}
                  </span>
                ),
              },
            ]}
            rows={detail.students}
            rowKey={(r) => r.id}
            emptyMessage="No students in this class yet. Add them from the Students page."
          />
        </>
      )}
    </Layout>
  );
}
