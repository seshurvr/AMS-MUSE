import { useEffect, useRef, useState } from 'react';
import type { DragEvent, FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner } from '../components/LoadingSpinner';
import { Button } from '../components/Button';
import { useToast } from '../context/ToastContext';
import { classesApi, attendanceApi, ApiError } from '../services/api';
import type { ClassItem, ImageQuality } from '../services/api';

type Step = 'details' | 'upload' | 'process';

function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function nowHM(): string {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

export function TakeAttendancePage() {
  const { success, error } = useToast();
  const navigate = useNavigate();
  const [step, setStep] = useState<Step>('details');
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [loadingClasses, setLoadingClasses] = useState(true);

  const [classId, setClassId] = useState('');
  const [date, setDate] = useState(todayISO());
  const [time, setTime] = useState(nowHM());
  const [subject, setSubject] = useState('');
  const [notes, setNotes] = useState('');
  const [formErrors, setFormErrors] = useState<Record<string, string>>({});
  const [creating, setCreating] = useState(false);

  const [sessionId, setSessionId] = useState<number | null>(null);
  const [sessionLabel, setSessionLabel] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [quality, setQuality] = useState<ImageQuality | null>(null);
  const [processing, setProcessing] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    void (async () => {
      try {
        const cls = await classesApi.list();
        setClasses(cls.filter((c) => c.status !== 'archived'));
      } catch (err) {
        error(err instanceof ApiError ? err.message : 'Failed to load classes.');
      } finally {
        setLoadingClasses(false);
      }
    })();
  }, [error]);

  useEffect(() => {
    return () => {
      if (previewUrl) URL.revokeObjectURL(previewUrl);
    };
  }, [previewUrl]);

  const stepIndex = step === 'details' ? 0 : step === 'upload' ? 1 : 2;

  const onCreateSession = async (e: FormEvent) => {
    e.preventDefault();
    const errs: Record<string, string> = {};
    if (!classId) errs.classId = 'Select a class.';
    if (!date) errs.date = 'Date is required.';
    if (!time) errs.time = 'Time is required.';
    if (!subject.trim()) errs.subject = 'Subject is required.';
    setFormErrors(errs);
    if (Object.keys(errs).length > 0) return;

    setCreating(true);
    try {
      const session = await attendanceApi.createSession({
        class_id: Number(classId),
        date,
        session_time: time,
        subject: subject.trim(),
        notes: notes.trim() || undefined,
      });
      const cls = classes.find((c) => c.id === Number(classId));
      setSessionId(session.id);
      setSessionLabel(`${cls?.name ?? 'Class'} · ${date} · ${time}`);
      setStep('upload');
      success('Session created. Now upload a classroom photo.');
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to create session.');
    } finally {
      setCreating(false);
    }
  };

  const pickFile = (f: File | null) => {
    if (!f) return;
    if (!f.type.startsWith('image/')) {
      error('Please choose an image file (JPEG, PNG, …).');
      return;
    }
    if (f.size > 20 * 1024 * 1024) {
      error('Image is larger than 20 MB. Please choose a smaller file.');
      return;
    }
    setQuality(null);
    setFile(f);
    if (previewUrl) URL.revokeObjectURL(previewUrl);
    setPreviewUrl(URL.createObjectURL(f));
  };

  const onDrop = (e: DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    pickFile(e.dataTransfer.files?.[0] ?? null);
  };

  const onUpload = async () => {
    if (!file || !sessionId) return;
    setUploading(true);
    try {
      const res = await attendanceApi.uploadImage(sessionId, file);
      setQuality(res.quality);
      setStep('process');
      success('Photo uploaded. Review the quality check, then process it.');
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Photo upload failed.');
    } finally {
      setUploading(false);
    }
  };

  const onProcess = async () => {
    if (!sessionId) return;
    setProcessing(true);
    try {
      const res = await attendanceApi.processImage(sessionId);
      success(`Detected ${res.count} ${res.count === 1 ? 'person' : 'people'} in the photo.`);
      navigate(`/attendance/${sessionId}/review`);
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Image processing failed.');
    } finally {
      setProcessing(false);
    }
  };

  const steps = ['Session details', 'Upload photo', 'Process & review'];

  return (
    <Layout title="Take Attendance">
      <ol className="mb-6 flex items-center gap-2 text-sm" aria-label="Progress">
        {steps.map((label, i) => (
          <li key={label} className="flex items-center gap-2">
            <span
              className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-semibold ${
                i < stepIndex
                  ? 'bg-emerald-600 text-white'
                  : i === stepIndex
                    ? 'bg-brand-600 text-white'
                    : 'bg-slate-200 text-slate-500'
              }`}
              aria-current={i === stepIndex ? 'step' : undefined}
            >
              {i < stepIndex ? '✓' : i + 1}
            </span>
            <span className={i === stepIndex ? 'font-semibold text-slate-900' : 'text-slate-500'}>{label}</span>
            {i < steps.length - 1 && <span className="mx-1 h-px w-8 bg-slate-300" aria-hidden="true" />}
          </li>
        ))}
      </ol>

      {step === 'details' && (
        <form onSubmit={onCreateSession} className="card max-w-2xl p-6" noValidate aria-label="New session details">
          <h2 className="text-base font-semibold text-slate-900">Session details</h2>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <label htmlFor="ta-class" className="label">Class</label>
              {loadingClasses ? (
                <LoadingSpinner label="Loading classes…" className="py-2" />
              ) : (
                <select id="ta-class" className="input" value={classId} onChange={(e) => setClassId(e.target.value)} aria-invalid={!!formErrors.classId}>
                  <option value="">Select a class…</option>
                  {classes.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name} ({c.section}) — {c.subject} · {c.student_count} students
                    </option>
                  ))}
                </select>
              )}
              {formErrors.classId && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.classId}</p>}
            </div>
            <div>
              <label htmlFor="ta-date" className="label">Date</label>
              <input id="ta-date" type="date" className="input" value={date} onChange={(e) => setDate(e.target.value)} max={todayISO()} />
              {formErrors.date && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.date}</p>}
            </div>
            <div>
              <label htmlFor="ta-time" className="label">Session time</label>
              <input id="ta-time" type="time" className="input" value={time} onChange={(e) => setTime(e.target.value)} />
              {formErrors.time && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.time}</p>}
            </div>
            <div className="sm:col-span-2">
              <label htmlFor="ta-subject" className="label">Subject</label>
              <input id="ta-subject" className="input" value={subject} onChange={(e) => setSubject(e.target.value)} placeholder="e.g. Mathematics" />
              {formErrors.subject && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.subject}</p>}
            </div>
            <div className="sm:col-span-2">
              <label htmlFor="ta-notes" className="label">Notes (optional)</label>
              <textarea id="ta-notes" className="input" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Anything worth noting about this session…" />
            </div>
          </div>
          <div className="mt-6 flex justify-end">
            <Button type="submit" loading={creating}>Create session & continue</Button>
          </div>
        </form>
      )}

      {step === 'upload' && (
        <div className="card max-w-3xl p-6">
          <h2 className="text-base font-semibold text-slate-900">Upload classroom photo</h2>
          <p className="mt-1 text-sm text-slate-500">
            Session: <span className="font-medium text-slate-700">{sessionLabel}</span>
          </p>
          <div
            role="button"
            tabIndex={0}
            aria-label="Drop a classroom photo here or press Enter to browse"
            onClick={() => fileInputRef.current?.click()}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') fileInputRef.current?.click();
            }}
            onDragOver={(e) => {
              e.preventDefault();
              setDragOver(true);
            }}
            onDragLeave={() => setDragOver(false)}
            onDrop={onDrop}
            className={`mt-4 flex min-h-48 cursor-pointer flex-col items-center justify-center rounded-xl border-2 border-dashed p-8 text-center transition-colors ${
              dragOver ? 'border-brand-500 bg-brand-50' : 'border-slate-300 bg-slate-50 hover:border-brand-400 hover:bg-brand-50/50'
            }`}
          >
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none" className="text-slate-400" aria-hidden="true">
              <rect x="3" y="4" width="18" height="14" rx="2" stroke="currentColor" strokeWidth="1.5" />
              <circle cx="12" cy="10" r="2.6" stroke="currentColor" strokeWidth="1.5" />
              <path d="M7 17c.8-1.6 2.6-2.6 5-2.6s4.2 1 5 2.6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
            <p className="mt-3 text-sm font-medium text-slate-700">
              Drag & drop your photo here, or <span className="text-brand-600 underline">browse files</span>
            </p>
            <p className="mt-1 text-xs text-slate-500">JPEG or PNG, up to 20 MB. Take the photo from the front of the classroom with faces clearly visible.</p>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={(e) => pickFile(e.target.files?.[0] ?? null)}
              aria-label="Choose photo"
            />
          </div>

          {file && previewUrl && (
            <div className="mt-4">
              <p className="text-sm font-medium text-slate-700">
                {file.name} <span className="font-normal text-slate-500">({(file.size / 1024 / 1024).toFixed(2)} MB)</span>
              </p>
              <div className="mt-2 overflow-hidden rounded-xl border border-slate-200 bg-slate-900">
                <img src={previewUrl} alt="Classroom photo preview" className="mx-auto max-h-80 object-contain" />
              </div>
              <div className="mt-2 flex gap-2">
                <Button variant="secondary" size="sm" onClick={() => { setFile(null); if (previewUrl) URL.revokeObjectURL(previewUrl); setPreviewUrl(null); }}>
                  Choose a different photo
                </Button>
              </div>
            </div>
          )}

          <div className="mt-6 flex justify-between">
            <Button variant="secondary" onClick={() => setStep('details')}>
              Back to details
            </Button>
            <Button loading={uploading} disabled={!file} onClick={onUpload}>
              Upload photo
            </Button>
          </div>
        </div>
      )}

      {step === 'process' && (
        <div className="card max-w-3xl p-6">
          <h2 className="text-base font-semibold text-slate-900">Photo quality check</h2>
          <p className="mt-1 text-sm text-slate-500">
            Session: <span className="font-medium text-slate-700">{sessionLabel}</span>
          </p>

          {previewUrl && (
            <div className="mt-4 overflow-hidden rounded-xl border border-slate-200 bg-slate-900">
              <img src={previewUrl} alt="Uploaded classroom photo" className="mx-auto max-h-80 object-contain" />
            </div>
          )}

          {quality && (
            <div className="mt-4 grid gap-3 sm:grid-cols-4">
              <div className="rounded-lg bg-slate-50 p-3">
                <p className="text-xs text-slate-500">Dimensions</p>
                <p className="font-semibold tabular-nums">{quality.width} × {quality.height}</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-3">
                <p className="text-xs text-slate-500">Brightness</p>
                <p className="font-semibold tabular-nums">{quality.brightness.toFixed(1)}</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-3">
                <p className="text-xs text-slate-500">Blur score</p>
                <p className="font-semibold tabular-nums">{quality.blur_score.toFixed(1)}</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-3">
                <p className="text-xs text-slate-500">Warnings</p>
                <p className="font-semibold tabular-nums">{quality.warnings.length}</p>
              </div>
            </div>
          )}

          {quality && quality.warnings.length > 0 && (
            <div role="alert" className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4">
              <p className="text-sm font-semibold text-amber-900">Photo quality warnings</p>
              <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-amber-800">
                {quality.warnings.map((w, i) => (
                  <li key={i}>{w}</li>
                ))}
              </ul>
              <p className="mt-2 text-xs text-amber-700">
                You can still continue, but detection accuracy may be lower. For best results, use a well-lit, sharp photo.
              </p>
            </div>
          )}

          <div className="mt-4 rounded-xl border border-slate-200 bg-slate-50 p-4 text-sm text-slate-600">
            <p className="font-medium text-slate-800">What happens next?</p>
            <p className="mt-1">
              The system will detect people in the photo and draw a box around each one. It does <strong>not</strong> identify anyone —
              you (the teacher) will map each box to a student and confirm the mapping yourself.
            </p>
          </div>

          <div className="mt-6 flex justify-between">
            <Button variant="secondary" onClick={() => setStep('upload')}>
              Back to upload
            </Button>
            <Button loading={processing} onClick={onProcess}>
              Process image
            </Button>
          </div>
        </div>
      )}
    </Layout>
  );
}
