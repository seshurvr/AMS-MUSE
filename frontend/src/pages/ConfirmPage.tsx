import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { Button } from '../components/Button';
import { AttendanceSummary } from '../components/AttendanceSummary';
import { useToast } from '../context/ToastContext';
import { attendanceApi, ApiError } from '../services/api';
import type { SessionDetail } from '../services/api';

export function ConfirmPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { success, error } = useToast();
  const sessionId = Number(id);

  const [detail, setDetail] = useState<SessionDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);

  const load = async () => {
    if (!Number.isFinite(sessionId)) return;
    setLoading(true);
    setLoadError(null);
    try {
      setDetail(await attendanceApi.getSession(sessionId));
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to load session.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const onConfirm = async () => {
    setConfirming(true);
    try {
      const res = await attendanceApi.finalize(sessionId);
      if (res.ok) {
        success('Attendance confirmed and saved.');
        navigate('/attendance/history');
      } else {
        error('The server did not confirm the session. Please try again.');
      }
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to finalize attendance.');
    } finally {
      setConfirming(false);
    }
  };

  return (
    <Layout title="Confirm Attendance">
      {loading ? (
        <LoadingSpinner label="Loading session…" />
      ) : loadError || !detail ? (
        <ErrorAlert message={loadError ?? 'Session not found.'} onRetry={load} />
      ) : (
        <div className="mx-auto max-w-3xl">
          <div className="card p-6">
            <h2 className="text-base font-semibold text-slate-900">Review before confirming</h2>
            <p className="mt-1 text-sm text-slate-500">
              Once confirmed, this session becomes read-only. Check the details below.
            </p>

            <dl className="mt-4 grid gap-3 sm:grid-cols-2">
              <div className="rounded-lg bg-slate-50 p-3">
                <dt className="text-xs text-slate-500">Class</dt>
                <dd className="font-semibold text-slate-900">{detail.session.class_name ?? `Class #${detail.session.class_id}`}</dd>
              </div>
              <div className="rounded-lg bg-slate-50 p-3">
                <dt className="text-xs text-slate-500">Date / time</dt>
                <dd className="font-semibold text-slate-900">{detail.session.date} · {detail.session.session_time}</dd>
              </div>
              <div className="rounded-lg bg-slate-50 p-3">
                <dt className="text-xs text-slate-500">Subject</dt>
                <dd className="font-semibold text-slate-900">{detail.session.subject}</dd>
              </div>
              <div className="rounded-lg bg-slate-50 p-3">
                <dt className="text-xs text-slate-500">Notes</dt>
                <dd className="font-semibold text-slate-900">{detail.session.notes || '—'}</dd>
              </div>
            </dl>

            <div className="mt-4 overflow-hidden rounded-xl border border-slate-200 bg-slate-900">
              <img src={detail.image_url} alt="Classroom photo for this session" className="mx-auto max-h-56 object-contain" />
            </div>

            <div className="mt-4">
              <AttendanceSummary summary={detail.summary} />
            </div>

            {detail.summary.needs_review > 0 && (
              <div role="alert" className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
                <p className="font-semibold text-amber-900">Heads up</p>
                <p className="mt-1">
                  {detail.summary.needs_review} {detail.summary.needs_review === 1 ? 'student still needs' : 'students still need'} review.
                  You can confirm anyway — the status stays “Needs review” until you update it.
                </p>
              </div>
            )}
          </div>

          <div className="mt-6 flex justify-between">
            <Button variant="secondary" onClick={() => navigate(`/attendance/${sessionId}/review`)}>
              Back to review
            </Button>
            <Button loading={confirming} onClick={onConfirm} disabled={detail.session.status === 'finalized'}>
              {detail.session.status === 'finalized' ? 'Already confirmed' : 'Confirm & save attendance'}
            </Button>
          </div>
        </div>
      )}
    </Layout>
  );
}
