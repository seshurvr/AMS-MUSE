import { useEffect, useMemo, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { DataTable } from '../components/DataTable';
import type { Column } from '../components/DataTable';
import { Modal } from '../components/Modal';
import { Button } from '../components/Button';
import { useToast } from '../context/ToastContext';
import { classesApi, studentsApi, ApiError } from '../services/api';
import type { ClassItem, Student } from '../services/api';

interface StudentForm {
  student_id: string;
  roll_number: string;
  name: string;
  email: string;
}

const emptyForm: StudentForm = { student_id: '', roll_number: '', name: '', email: '' };

export function StudentsPage() {
  const { success, error } = useToast();
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [classId, setClassId] = useState<number | ''>('');
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [showArchived, setShowArchived] = useState(false);
  const [sortKey, setSortKey] = useState('roll_number');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc');

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<Student | null>(null);
  const [form, setForm] = useState<StudentForm>(emptyForm);
  const [formErrors, setFormErrors] = useState<Partial<StudentForm>>({});
  const [saving, setSaving] = useState(false);
  const [confirmArchive, setConfirmArchive] = useState<Student | null>(null);
  const [importing, setImporting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    void (async () => {
      try {
        const cls = await classesApi.list();
        setClasses(cls.filter((c) => c.status !== 'archived'));
        if (cls.length > 0) setClassId(cls[0].id);
      } catch (err) {
        error(err instanceof ApiError ? err.message : 'Failed to load classes.');
      } finally {
        setLoading(false);
      }
    })();
  }, [error]);

  const loadStudents = async (cid: number) => {
    setLoading(true);
    setLoadError(null);
    try {
      setStudents(await classesApi.students(cid));
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to load students.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (classId) void loadStudents(classId);
    else setStudents([]);
  }, [classId]);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    let list = students.filter((s) => (showArchived ? true : s.status !== 'archived'));
    if (q) {
      list = list.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          s.roll_number.toLowerCase().includes(q) ||
          s.student_id.toLowerCase().includes(q) ||
          (s.email ?? '').toLowerCase().includes(q),
      );
    }
    const dir = sortDir === 'asc' ? 1 : -1;
    return [...list].sort((a, b) => {
      const av = String((a as unknown as Record<string, string>)[sortKey] ?? '');
      const bv = String((b as unknown as Record<string, string>)[sortKey] ?? '');
      return av.localeCompare(bv, undefined, { numeric: true }) * dir;
    });
  }, [students, search, showArchived, sortKey, sortDir]);

  const onSort = (key: string) => {
    if (key === sortKey) setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'));
    else {
      setSortKey(key);
      setSortDir('asc');
    }
  };

  const openCreate = () => {
    if (!classId) {
      error('Select a class first.');
      return;
    }
    setEditing(null);
    setForm(emptyForm);
    setFormErrors({});
    setModalOpen(true);
  };

  const openEdit = (s: Student) => {
    setEditing(s);
    setForm({ student_id: s.student_id, roll_number: s.roll_number, name: s.name, email: s.email ?? '' });
    setFormErrors({});
    setModalOpen(true);
  };

  const validate = (): boolean => {
    const e: Partial<StudentForm> = {};
    if (!form.student_id.trim()) e.student_id = 'Student ID is required.';
    if (!form.roll_number.trim()) e.roll_number = 'Roll number is required.';
    if (!form.name.trim()) e.name = 'Name is required.';
    if (form.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) e.email = 'Enter a valid email address.';
    setFormErrors(e);
    return Object.keys(e).length === 0;
  };

  const onSave = async (ev: FormEvent) => {
    ev.preventDefault();
    if (!validate() || !classId) return;
    setSaving(true);
    try {
      const payload = {
        student_id: form.student_id.trim(),
        roll_number: form.roll_number.trim(),
        name: form.name.trim(),
        email: form.email.trim() || undefined,
      };
      if (editing) {
        await studentsApi.update(editing.id, payload);
        success('Student updated.');
      } else {
        await studentsApi.create({ class_id: classId, ...payload });
        success('Student added.');
      }
      setModalOpen(false);
      await loadStudents(classId);
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to save student.');
    } finally {
      setSaving(false);
    }
  };

  const onArchiveToggle = async (s: Student) => {
    const next = s.status === 'archived' ? 'active' : 'archived';
    try {
      await studentsApi.update(s.id, { status: next });
      success(next === 'archived' ? 'Student archived.' : 'Student restored.');
      setConfirmArchive(null);
      if (classId) await loadStudents(classId);
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to update student.');
    }
  };

  const onImportFile = async (file: File) => {
    if (!classId) return;
    setImporting(true);
    try {
      const res = await classesApi.importStudents(classId, file);
      const skipped = res.skipped ? ` Skipped ${res.skipped}.` : '';
      success(`Imported ${res.imported} students.${skipped}`);
      await loadStudents(classId);
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'CSV import failed.');
    } finally {
      setImporting(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const onExport = async () => {
    if (!classId) return;
    try {
      await classesApi.exportStudents(classId);
      success('Roster exported.');
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Export failed.');
    }
  };

  const columns: Column<Student>[] = [
    { key: 'roll_number', header: 'Roll no.', sortable: true, render: (r) => r.roll_number },
    { key: 'name', header: 'Name', sortable: true, render: (r) => <span className="font-medium">{r.name}</span> },
    { key: 'student_id', header: 'Student ID', sortable: true, render: (r) => <span className="font-mono text-xs">{r.student_id}</span> },
    { key: 'email', header: 'Email', render: (r) => r.email ?? <span className="text-slate-400">—</span> },
    {
      key: 'status',
      header: 'Status',
      render: (r) =>
        r.status === 'archived' ? (
          <span className="inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-600 ring-1 ring-inset ring-slate-600/10">Archived</span>
        ) : (
          <span className="inline-flex rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-800 ring-1 ring-inset ring-emerald-600/20">Active</span>
        ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <span className="flex flex-wrap gap-1.5">
          <Button size="sm" variant="secondary" onClick={() => openEdit(r)}>Edit</Button>
          <Button
            size="sm"
            variant="ghost"
            className={r.status === 'archived' ? 'text-emerald-700' : 'text-amber-700'}
            onClick={() => setConfirmArchive(r)}
          >
            {r.status === 'archived' ? 'Restore' : 'Archive'}
          </Button>
        </span>
      ),
    },
  ];

  return (
    <Layout title="Students">
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="min-w-48">
          <label htmlFor="class-select" className="sr-only">Select class</label>
          <select
            id="class-select"
            className="input"
            value={classId}
            onChange={(e) => setClassId(e.target.value ? Number(e.target.value) : '')}
          >
            <option value="">Select a class…</option>
            {classes.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name} ({c.section}) — {c.subject}
              </option>
            ))}
          </select>
        </div>
        <div className="relative flex-1 sm:max-w-xs">
          <label htmlFor="student-search" className="sr-only">Search students</label>
          <input
            id="student-search"
            className="input pl-9"
            placeholder="Search name, roll no., ID…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <span className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" aria-hidden="true">
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
              <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
              <path d="M11 11l3.5 3.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </span>
        </div>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          <Button variant="secondary" onClick={() => fileInputRef.current?.click()} loading={importing} disabled={!classId}>
            Import CSV
          </Button>
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv,text/csv"
            className="hidden"
            aria-label="Import students CSV"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void onImportFile(f);
            }}
          />
          <Button variant="secondary" onClick={onExport} disabled={!classId}>
            Export CSV
          </Button>
          <Button onClick={openCreate} disabled={!classId}>
            Add student
          </Button>
        </div>
      </div>

      <div className="mb-3 flex items-center gap-3">
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input
            type="checkbox"
            checked={showArchived}
            onChange={(e) => setShowArchived(e.target.checked)}
            className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500"
          />
          Show archived
        </label>
        <span className="text-sm text-slate-500 tabular-nums">{rows.length} of {students.length} students</span>
      </div>

      {loading ? (
        <LoadingSpinner label="Loading students…" />
      ) : loadError ? (
        <ErrorAlert message={loadError} onRetry={() => classId && loadStudents(classId)} />
      ) : !classId ? (
        <div className="card p-10 text-center text-sm text-slate-500">
          Select a class to view and manage its students.
        </div>
      ) : (
        <DataTable<Student>
          ariaLabel="Students"
          columns={columns}
          rows={rows}
          rowKey={(r) => r.id}
          emptyMessage={search ? 'No students match your search.' : 'No students yet. Add one or import a CSV.'}
          sortKey={sortKey}
          sortDir={sortDir}
          onSort={onSort}
        />
      )}

      <Modal
        open={modalOpen}
        title={editing ? 'Edit student' : 'Add student'}
        onClose={() => setModalOpen(false)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setModalOpen(false)}>Cancel</Button>
            <Button loading={saving} onClick={onSave}>{editing ? 'Save changes' : 'Add student'}</Button>
          </>
        }
      >
        <form onSubmit={onSave} className="space-y-4" noValidate>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label htmlFor="stu-id" className="label">Student ID</label>
              <input id="stu-id" className="input font-mono" value={form.student_id} onChange={(e) => setForm({ ...form, student_id: e.target.value })} />
              {formErrors.student_id && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.student_id}</p>}
            </div>
            <div>
              <label htmlFor="stu-roll" className="label">Roll number</label>
              <input id="stu-roll" className="input" value={form.roll_number} onChange={(e) => setForm({ ...form, roll_number: e.target.value })} />
              {formErrors.roll_number && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.roll_number}</p>}
            </div>
          </div>
          <div>
            <label htmlFor="stu-name" className="label">Full name</label>
            <input id="stu-name" className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            {formErrors.name && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.name}</p>}
          </div>
          <div>
            <label htmlFor="stu-email" className="label">Email (optional)</label>
            <input id="stu-email" type="email" className="input" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            {formErrors.email && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.email}</p>}
          </div>
        </form>
      </Modal>

      <Modal
        open={confirmArchive !== null}
        title={confirmArchive?.status === 'archived' ? 'Restore student' : 'Archive student'}
        onClose={() => setConfirmArchive(null)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setConfirmArchive(null)}>Cancel</Button>
            <Button variant={confirmArchive?.status === 'archived' ? 'primary' : 'danger'} onClick={() => confirmArchive && onArchiveToggle(confirmArchive)}>
              {confirmArchive?.status === 'archived' ? 'Restore' : 'Archive'}
            </Button>
          </>
        }
      >
        <p className="text-sm text-slate-600">
          {confirmArchive?.status === 'archived'
            ? `Restore ${confirmArchive?.name} to the active roster?`
            : `Archive ${confirmArchive?.name}? Archived students are excluded from new attendance sessions but their past records are kept.`}
        </p>
      </Modal>
    </Layout>
  );
}
