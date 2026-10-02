import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { Button } from '../components/Button';
import { ImageViewer } from '../components/ImageViewer';
import { DetectionOverlay } from '../components/DetectionOverlay';
import { AttendanceStatusBadge } from '../components/AttendanceStatusBadge';
import { AttendanceSummary } from '../components/AttendanceSummary';
import { useToast } from '../context/ToastContext';
import { classesApi, attendanceApi, ApiError } from '../services/api';
import type { SessionDetail, Student } from '../services/api';

export function SessionDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { error } = useToast();
  const sessionId = Number(id);

  const [detail, setDetail] = useState<SessionDetail | null>(null);
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [naturalSize, setNaturalSize] = useState({ w: 0, h: 0 });

  const load = async () => {
    if (!Number.isFinite(sessionId)) return;
    setLoading(true);
    setLoadError(null);
    try {
      const d = await attendanceApi.getSession(sessionId);
      setDetail(d);
      const cls = await classesApi.get(d.session.class_id);
      setStudents(cls.students);
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

  const studentById = useMemo(() => new Map(students.map((s) => [s.id, s])), [students]);

  const mappedNames = useMemo(() => {
    const m = new Map<number, string>();
    for (const r of detail?.records ?? []) {
      if (r.detection_id != null && r.student_id != null) {
        const s = studentById.get(r.student_id);
        if (s) m.set(r.detection_id, s.name);
      }
    }
    return m;
  }, [detail, studentById]);

  const isFinalized = detail?.session.status === 'finalized';

  return (
    <Layout title="Session Detail">
      <div className="mb-4 flex items-center justify-between">
        <Link to="/attendance/history" className="btn-focus text-sm font-medium text-brand-600 hover:underline">
          ← Back to history
        </Link>
        {detail && !isFinalized && (
          <Button onClick={() => navigate(`/attendance/${sessionId}/review`)}>
            Edit (review)
          </Button>
        )}
      </div>

      {loading ? (
        <LoadingSpinner label="Loading session…" />
      ) : loadError || !detail ? (
        <ErrorAlert message={loadError ?? 'Session not found.'} onRetry={load} />
      ) : (
        <>
          <div className="card mb-4 flex flex-wrap items-center gap-x-6 gap-y-2 p-4 text-sm">
            <div>
              <p className="text-xs text-slate-500">Class</p>
              <p className="font-semibold text-slate-900">{detail.session.class_name ?? `Class #${detail.session.class_id}`}</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">Date / time</p>
              <p className="font-semibold text-slate-900">{detail.session.date} · {detail.session.session_time}</p>
            </div>
            <div>
              <p className="text-xs text-slate-500">Subject</p>
              <p className="font-semibold text-slate-900">{detail.session.subject}</p>
            </div>
            <div className="ml-auto">
              {isFinalized ? (
                <span className="inline-flex rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700 ring-1 ring-inset ring-slate-600/10">Finalized</span>
              ) : (
                <span className="inline-flex rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-900 ring-1 ring-inset ring-amber-600/20">Draft</span>
              )}
            </div>
          </div>

          {detail.session.notes && (
            <div className="card mb-4 p-4 text-sm">
              <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Notes</p>
              <p className="mt-1 text-slate-800">{detail.session.notes}</p>
            </div>
          )}

          <div className="grid gap-4 lg:grid-cols-2">
            <div>
              <ImageViewer
                src={detail.image_url}
                alt="Classroom photo with detected people boxes"
                onNaturalSize={(w, h) => setNaturalSize({ w, h })}
              >
                <DetectionOverlay
                  detections={detail.detections}
                  imageWidth={naturalSize.w}
                  imageHeight={naturalSize.h}
                  mappedNames={mappedNames}
                />
              </ImageViewer>
              <p className="mt-2 text-xs text-slate-500">
                {detail.detections.length} {detail.detections.length === 1 ? 'person' : 'people'} detected. Boxes show the teacher-confirmed student name where mapped.
              </p>
            </div>
            <div>
              <AttendanceSummary summary={detail.summary} />
              <h2 className="mb-2 mt-4 text-sm font-semibold text-slate-900">Mappings</h2>
              <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm">
                <table className="min-w-full divide-y divide-slate-200 text-sm" aria-label="Detection mappings">
                  <thead className="bg-slate-50">
                    <tr>
                      <th scope="col" className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Detection</th>
                      <th scope="col" className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Student</th>
                      <th scope="col" className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Confirmed</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {detail.detections.length === 0 ? (
                      <tr>
                        <td colSpan={3} className="px-4 py-6 text-center text-slate-500">No detections for this session.</td>
                      </tr>
                    ) : (
                      detail.detections
                        .slice()
                        .sort((a, b) => a.detection_number - b.detection_number)
                        .map((d) => {
                          const rec = detail.records.find((r) => r.detection_id === d.id);
                          const s = rec ? studentById.get(rec.student_id) : undefined;
                          return (
                            <tr key={d.id}>
                              <td className="px-4 py-2.5 font-medium">Person {d.detection_number} <span className="font-normal text-slate-500">({Math.round(d.confidence * 100)}%)</span></td>
                              <td className="px-4 py-2.5">{s ? `${s.name} (${s.roll_number})` : <span className="text-slate-400">Unmapped</span>}</td>
                              <td className="px-4 py-2.5">
                                {rec?.manually_confirmed ? (
                                  <span className="inline-flex items-center gap-1 text-xs font-medium text-emerald-700">
                                    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
                                      <circle cx="6" cy="6" r="5.4" stroke="currentColor" strokeWidth="1.4" />
                                      <path d="M4 6.2l1.5 1.5L8.2 4.6" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
                                    </svg>
                                    Teacher-confirmed
                                  </span>
                                ) : (
                                  <span className="text-xs text-slate-400">—</span>
                                )}
                              </td>
                            </tr>
                          );
                        })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <h2 className="mb-3 mt-8 text-base font-semibold text-slate-900">Attendance records</h2>
          <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm">
            <table className="min-w-full divide-y divide-slate-200 text-sm" aria-label="Attendance records">
              <thead className="bg-slate-50">
                <tr>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Roll no.</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Name</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Source</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Status</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {students.map((s) => {
                  const rec = detail.records.find((r) => r.student_id === s.id);
                  const status = rec?.status ?? 'needs_review';
                  return (
                    <tr key={s.id}>
                      <td className="px-4 py-2.5">{s.roll_number}</td>
                      <td className="px-4 py-2.5 font-medium">{s.name}</td>
                      <td className="px-4 py-2.5">
                        {rec?.detection_id != null ? (
                          <span className="inline-flex rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800">Photo</span>
                        ) : (
                          <span className="inline-flex rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">Manual</span>
                        )}
                      </td>
                      <td className="px-4 py-2.5"><AttendanceStatusBadge status={status} size="sm" /></td>
                      <td className="px-4 py-2.5 text-slate-500">{rec?.notes ?? '—'}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </>
      )}
    </Layout>
  );
}
