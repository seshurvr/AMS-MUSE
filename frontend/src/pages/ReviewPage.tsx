import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { Button } from '../components/Button';
import { ImageViewer } from '../components/ImageViewer';
import { DetectionOverlay } from '../components/DetectionOverlay';
import { StudentSelector } from '../components/StudentSelector';
import { AttendanceStatusBadge } from '../components/AttendanceStatusBadge';
import { useToast } from '../context/ToastContext';
import { classesApi, attendanceApi, ApiError } from '../services/api';
import type { AttendanceStatus, Detection, SessionDetail, Student } from '../services/api';

const STATUS_OPTIONS: { value: AttendanceStatus; label: string }[] = [
  { value: 'present', label: 'Present' },
  { value: 'absent', label: 'Absent' },
  { value: 'excused', label: 'Excused' },
  { value: 'needs_review', label: 'Needs Review' },
];

const LOW_CONFIDENCE_THRESHOLD = 0.5;

export function ReviewPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { success, error } = useToast();
  const sessionId = Number(id);

  const [detail, setDetail] = useState<SessionDetail | null>(null);
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  // detectionId -> studentId (teacher-confirmed manual mapping)
  const [mapping, setMapping] = useState<Map<number, number | null>>(new Map());
  // studentId -> status
  const [statuses, setStatuses] = useState<Map<number, AttendanceStatus>>(new Map());
  const [selectedDetId, setSelectedDetId] = useState<number | null>(null);
  const [naturalSize, setNaturalSize] = useState({ w: 0, h: 0 });
  const [saving, setSaving] = useState(false);
  const rowRefs = useRef<Map<number, HTMLDivElement>>(new Map());

  const load = async () => {
    if (!Number.isFinite(sessionId)) return;
    setLoading(true);
    setLoadError(null);
    try {
      const d = await attendanceApi.getSession(sessionId);
      setDetail(d);
      const cls = await classesApi.get(d.session.class_id);
      const roster = cls.students.filter((s) => s.status !== 'archived');
      setStudents(roster);

      const map = new Map<number, number | null>();
      const st = new Map<number, AttendanceStatus>();
      for (const det of d.detections) map.set(det.id, null);
      for (const r of d.records) {
        if (r.detection_id != null) map.set(r.detection_id, r.student_id);
        st.set(r.student_id, r.status);
      }
      // Defaults for students without a saved record:
      for (const s of roster) {
        if (!st.has(s.id)) {
          const isMapped = [...map.values()].includes(s.id);
          st.set(s.id, isMapped ? 'present' : 'needs_review');
        }
      }
      setMapping(map);
      setStatuses(st);
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

  const isFinalized = detail?.session.status === 'finalized';

  const studentById = useMemo(() => new Map(students.map((s) => [s.id, s])), [students]);

  const takenStudentIds = useMemo(() => {
    const set = new Set<number>();
    for (const sid of mapping.values()) if (sid != null) set.add(sid);
    return set;
  }, [mapping]);

  const duplicates = useMemo(() => {
    const counts = new Map<number, number>();
    for (const sid of mapping.values()) {
      if (sid != null) counts.set(sid, (counts.get(sid) ?? 0) + 1);
    }
    return new Map([...counts.entries()].filter(([, c]) => c > 1));
  }, [mapping]);

  const mappedNames = useMemo(() => {
    const m = new Map<number, string>();
    for (const [detId, sid] of mapping.entries()) {
      if (sid != null) {
        const s = studentById.get(sid);
        if (s) m.set(detId, s.name);
      }
    }
    return m;
  }, [mapping, studentById]);

  const summary = useMemo(() => {
    let present = 0, absent = 0, excused = 0, needs_review = 0;
    for (const s of students) {
      const st = statuses.get(s.id) ?? 'needs_review';
      if (st === 'present') present++;
      else if (st === 'absent') absent++;
      else if (st === 'excused') excused++;
      else needs_review++;
    }
    const eligible = students.length - excused;
    const pct = eligible > 0 ? (present / eligible) * 100 : 0;
    return { total: students.length, detected: takenStudentIds.size, present, absent, excused, needs_review, attendance_percentage: pct };
  }, [students, statuses, takenStudentIds]);

  const warnings = useMemo(() => {
    const list: string[] = [];
    const unmapped = detail?.detections.filter((d) => mapping.get(d.id) == null) ?? [];
    if (unmapped.length > 0) {
      list.push(`${unmapped.length} detected ${unmapped.length === 1 ? 'person' : 'people'} (${unmapped.map((d) => `Person ${d.detection_number}`).join(', ')}) ${unmapped.length === 1 ? 'is' : 'are'} not mapped to a student.`);
    }
    if (duplicates.size > 0) {
      const names = [...duplicates.keys()].map((sid) => studentById.get(sid)?.name ?? `#${sid}`);
      list.push(`Duplicate mapping: ${names.join(', ')} ${duplicates.size === 1 ? 'is' : 'are'} mapped to more than one box.`);
    }
    const lowConf = detail?.detections.filter((d) => d.confidence < LOW_CONFIDENCE_THRESHOLD) ?? [];
    if (lowConf.length > 0) {
      list.push(`${lowConf.length} detection${lowConf.length === 1 ? '' : 's'} below 50% confidence — verify carefully.`);
    }
    if (summary.needs_review > 0) {
      list.push(`${summary.needs_review} ${summary.needs_review === 1 ? 'student still needs' : 'students still need'} review before finalizing.`);
    }
    return list;
  }, [detail, mapping, duplicates, studentById, summary]);

  const setMap = (detId: number, studentId: number | null) => {
    if (isFinalized) return;
    setMapping((prev) => {
      const next = new Map(prev);
      next.set(detId, studentId);
      return next;
    });
    setStatuses((prev) => {
      const next = new Map(prev);
      if (studentId != null && (next.get(studentId) === 'needs_review' || next.get(studentId) === 'absent')) {
        next.set(studentId, 'present');
      }
      return next;
    });
  };

  const buildRecords = () =>
    students.map((s) => {
      let detection_id: number | null = null;
      for (const [detId, sid] of mapping.entries()) {
        if (sid === s.id) {
          detection_id = detId;
          break;
        }
      }
      return {
        student_id: s.id,
        status: statuses.get(s.id) ?? 'needs_review',
        detection_id,
        manually_confirmed: detection_id != null,
      };
    });

  const onSaveDraft = async () => {
    setSaving(true);
    try {
      const updated = await attendanceApi.saveRecords(sessionId, buildRecords());
      setDetail(updated);
      success('Draft saved.');
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to save draft.');
    } finally {
      setSaving(false);
    }
  };

  const onContinue = async () => {
    setSaving(true);
    try {
      await attendanceApi.saveRecords(sessionId, buildRecords());
      navigate(`/attendance/${sessionId}/confirm`);
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to save draft.');
      setSaving(false);
    }
  };

  const selectDetection = (detId: number) => {
    setSelectedDetId(detId);
    const el = rowRefs.current.get(detId);
    el?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  };

  return (
    <Layout title="Review Attendance">
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
                <span className="inline-flex items-center rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700 ring-1 ring-inset ring-slate-600/10">
                  Finalized — read only
                </span>
              ) : (
                <span className="inline-flex items-center rounded-full bg-amber-100 px-3 py-1 text-xs font-semibold text-amber-900 ring-1 ring-inset ring-amber-600/20">
                  Draft — awaiting your review
                </span>
              )}
            </div>
          </div>

          {isFinalized && (
            <div role="alert" className="mb-4 rounded-xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
              This session is finalized and can no longer be edited. Mappings and statuses are shown for reference.{' '}
              <Link to={`/attendance/${sessionId}`} className="font-medium text-brand-600 hover:underline">View session detail</Link>
            </div>
          )}

          <div className="rounded-xl border border-brand-200 bg-brand-50 p-4 text-sm text-brand-900">
            <p className="font-semibold">Teacher-confirmed mapping</p>
            <p className="mt-1">
              The system only detects <em>people boxes</em> — it does not identify anyone. Click a box, then choose the matching student
              from the list. Every mapping is recorded as <strong>manually confirmed by you</strong>.
            </p>
          </div>

          <div className="mt-4 grid gap-4 lg:grid-cols-3">
            {/* Left: image with detection overlay */}
            <div className="lg:col-span-2">
              <ImageViewer
                src={detail.image_url}
                alt="Classroom photo with detected people boxes"
                onNaturalSize={(w, h) => setNaturalSize({ w, h })}
              >
                <DetectionOverlay
                  detections={detail.detections}
                  imageWidth={naturalSize.w}
                  imageHeight={naturalSize.h}
                  selectedId={selectedDetId}
                  onSelect={selectDetection}
                  mappedNames={mappedNames}
                />
              </ImageViewer>
              <p className="mt-2 text-xs text-slate-500">
                {detail.detections.length} {detail.detections.length === 1 ? 'person' : 'people'} detected. Click a box to jump to its mapping row.
              </p>
            </div>

            {/* Right: mapping panel */}
            <div className="card flex max-h-[70vh] flex-col p-4">
              <h2 className="text-sm font-semibold text-slate-900">
                Map detections to students
                <span className="ml-2 font-normal text-slate-500">
                  {takenStudentIds.size}/{detail.detections.length} mapped
                </span>
              </h2>
              <div className="mt-3 flex-1 space-y-3 overflow-y-auto pr-1">
                {detail.detections
                  .slice()
                  .sort((a, b) => a.detection_number - b.detection_number)
                  .map((d: Detection) => {
                    const mappedId = mapping.get(d.id) ?? null;
                    const selected = selectedDetId === d.id;
                    return (
                      <div
                        key={d.id}
                        ref={(el) => {
                          if (el) rowRefs.current.set(d.id, el);
                          else rowRefs.current.delete(d.id);
                        }}
                        className={`rounded-lg border p-3 ${selected ? 'border-brand-500 ring-2 ring-brand-200' : 'border-slate-200'}`}
                      >
                        <div className="mb-2 flex items-center justify-between">
                          <button
                            type="button"
                            onClick={() => selectDetection(d.id)}
                            className="btn-focus rounded text-sm font-semibold text-slate-900 hover:text-brand-700"
                          >
                            Person {d.detection_number}
                          </button>
                          <span className="text-xs tabular-nums text-slate-500">
                            Confidence {Math.round(d.confidence * 100)}%
                            {d.confidence < LOW_CONFIDENCE_THRESHOLD && (
                              <span className="ml-1 font-semibold text-amber-700">(low)</span>
                            )}
                          </span>
                        </div>
                        <StudentSelector
                          students={students}
                          value={mappedId}
                          onChange={(sid) => setMap(d.id, sid)}
                          label={`Map Person ${d.detection_number} to a student`}
                          placeholder="Search student to map…"
                          disabled={isFinalized}
                          takenStudentIds={takenStudentIds}
                        />
                        {mappedId != null && (
                          <p className="mt-1.5 flex items-center gap-1 text-xs font-medium text-emerald-700">
                            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
                              <circle cx="6" cy="6" r="5.4" stroke="currentColor" strokeWidth="1.4" />
                              <path d="M4 6.2l1.5 1.5L8.2 4.6" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                            Teacher-confirmed
                          </p>
                        )}
                      </div>
                    );
                  })}
                {detail.detections.length === 0 && (
                  <p className="text-sm text-slate-500">No detections. All students will need manual status review below.</p>
                )}
              </div>
            </div>
          </div>

          {/* Roster table */}
          <h2 className="mb-3 mt-8 text-base font-semibold text-slate-900">Full roster</h2>
          <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm">
            <table className="min-w-full divide-y divide-slate-200 text-sm" aria-label="Student attendance roster">
              <thead className="bg-slate-50">
                <tr>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Roll no.</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Name</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Source</th>
                  <th scope="col" className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {students.map((s) => {
                  let detection_id: number | null = null;
                  let detNum: number | null = null;
                  for (const [detId, sid] of mapping.entries()) {
                    if (sid === s.id) {
                      detection_id = detId;
                      detNum = detail.detections.find((d) => d.id === detId)?.detection_number ?? null;
                      break;
                    }
                  }
                  const status = statuses.get(s.id) ?? 'needs_review';
                  return (
                    <tr key={s.id} className={duplicates.has(s.id) ? 'bg-amber-50/50' : ''}>
                      <td className="px-4 py-2.5">{s.roll_number}</td>
                      <td className="px-4 py-2.5 font-medium">
                        {s.name}
                        {duplicates.has(s.id) && (
                          <span className="ml-2 rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-800">
                            Mapped twice
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-2.5">
                        {detection_id != null ? (
                          <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium text-emerald-800">
                            Photo · Person {detNum}
                          </span>
                        ) : (
                          <span className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-600">
                            Manual
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-2.5">
                        {isFinalized ? (
                          <AttendanceStatusBadge status={status} size="sm" />
                        ) : (
                          <label className="flex items-center gap-2">
                            <span className="sr-only">Attendance status for {s.name}</span>
                            <select
                              className="input !w-auto"
                              value={status}
                              onChange={(e) =>
                                setStatuses((prev) => new Map(prev).set(s.id, e.target.value as AttendanceStatus))
                              }
                            >
                              {STATUS_OPTIONS.map((o) => (
                                <option key={o.value} value={o.value}>{o.label}</option>
                              ))}
                            </select>
                          </label>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Summary + warnings */}
          <div className="mt-6 grid gap-4 lg:grid-cols-3">
            <div className="lg:col-span-2">
              <div className="card p-4">
                <div className="flex flex-wrap gap-x-8 gap-y-3">
                  <Stat label="Present" value={summary.present} tone="text-emerald-700" />
                  <Stat label="Absent" value={summary.absent} tone="text-red-700" />
                  <Stat label="Excused" value={summary.excused} tone="text-sky-700" />
                  <Stat label="Needs review" value={summary.needs_review} tone="text-amber-700" />
                  <div className="ml-auto text-right">
                    <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Attendance</p>
                    <p className="text-2xl font-bold text-slate-900">{Math.round(summary.attendance_percentage)}%</p>
                  </div>
                </div>
                <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-slate-100" role="img" aria-label={`Attendance ${Math.round(summary.attendance_percentage)} percent`}>
                  <div className="h-full rounded-full bg-brand-600" style={{ width: `${Math.round(summary.attendance_percentage)}%` }} />
                </div>
              </div>
            </div>
            <div className="card p-4" aria-label="Review warnings">
              <h3 className="text-sm font-semibold text-slate-900">Warnings ({warnings.length})</h3>
              {warnings.length === 0 ? (
                <p className="mt-2 flex items-center gap-1.5 text-sm text-emerald-700">
                  <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
                    <circle cx="7" cy="7" r="6.2" stroke="currentColor" strokeWidth="1.4" />
                    <path d="M4.5 7.2l1.8 1.8 3.2-3.8" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                  Everything looks good.
                </p>
              ) : (
                <ul className="mt-2 list-disc space-y-1.5 pl-5 text-sm text-amber-800">
                  {warnings.map((w, i) => (
                    <li key={i}>{w}</li>
                  ))}
                </ul>
              )}
            </div>
          </div>

          <div className="sticky bottom-0 mt-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white/95 p-4 shadow-lg backdrop-blur">
            <Button variant="secondary" onClick={() => navigate('/attendance/history')}>
              Back
            </Button>
            {!isFinalized && (
              <div className="flex gap-2">
                <Button variant="secondary" loading={saving} onClick={onSaveDraft}>
                  Save draft
                </Button>
                <Button loading={saving} onClick={onContinue}>
                  Continue to confirmation
                </Button>
              </div>
            )}
          </div>
        </>
      )}
    </Layout>
  );
}

function Stat({ label, value, tone }: { label: string; value: number; tone: string }) {
  return (
    <div>
      <p className="text-xs font-medium uppercase tracking-wide text-slate-500">{label}</p>
      <p className={`text-2xl font-bold tabular-nums ${tone}`}>{value}</p>
    </div>
  );
}
