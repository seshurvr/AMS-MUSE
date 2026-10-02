import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { LoadingSpinner, ErrorAlert } from '../components/LoadingSpinner';
import { DataTable } from '../components/DataTable';
import { Modal } from '../components/Modal';
import { Button } from '../components/Button';
import { useToast } from '../context/ToastContext';
import { classesApi, ApiError } from '../services/api';
import type { ClassItem } from '../services/api';

interface ClassForm {
  name: string;
  section: string;
  subject: string;
  academic_year: string;
}

const emptyForm: ClassForm = { name: '', section: '', subject: '', academic_year: '' };

export function ClassesPage() {
  const { success, error } = useToast();
  const navigate = useNavigate();
  const [classes, setClasses] = useState<ClassItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<ClassItem | null>(null);
  const [form, setForm] = useState<ClassForm>(emptyForm);
  const [formErrors, setFormErrors] = useState<Partial<ClassForm>>({});
  const [saving, setSaving] = useState(false);
  const [confirmArchive, setConfirmArchive] = useState<ClassItem | null>(null);
  const [showArchived, setShowArchived] = useState(false);

  const load = async () => {
    setLoading(true);
    setLoadError(null);
    try {
      setClasses(await classesApi.list());
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : 'Failed to load classes.';
      setLoadError(msg);
      error(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setFormErrors({});
    setModalOpen(true);
  };

  const openEdit = (c: ClassItem) => {
    setEditing(c);
    setForm({ name: c.name, section: c.section, subject: c.subject, academic_year: c.academic_year });
    setFormErrors({});
    setModalOpen(true);
  };

  const validate = (): boolean => {
    const e: Partial<ClassForm> = {};
    if (!form.name.trim()) e.name = 'Class name is required.';
    if (!form.section.trim()) e.section = 'Section is required.';
    if (!form.subject.trim()) e.subject = 'Subject is required.';
    if (!form.academic_year.trim()) e.academic_year = 'Academic year is required.';
    setFormErrors(e);
    return Object.keys(e).length === 0;
  };

  const onSave = async (ev: FormEvent) => {
    ev.preventDefault();
    if (!validate()) return;
    setSaving(true);
    try {
      if (editing) {
        await classesApi.update(editing.id, form);
        success('Class updated.');
      } else {
        await classesApi.create(form);
        success('Class created.');
      }
      setModalOpen(false);
      await load();
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to save class.');
    } finally {
      setSaving(false);
    }
  };

  const onArchiveToggle = async (c: ClassItem) => {
    const next = c.status === 'archived' ? 'active' : 'archived';
    try {
      await classesApi.update(c.id, { status: next });
      success(next === 'archived' ? 'Class archived.' : 'Class restored.');
      setConfirmArchive(null);
      await load();
    } catch (err) {
      error(err instanceof ApiError ? err.message : 'Failed to update class.');
    }
  };

  const visible = showArchived ? classes : classes.filter((c) => c.status !== 'archived');

  return (
    <Layout title="Classes">
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <Button onClick={openCreate}>
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
            <path d="M7 2.5v9M2.5 7h9" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
          New class
        </Button>
        <label className="ml-auto flex items-center gap-2 text-sm text-slate-600">
          <input
            type="checkbox"
            checked={showArchived}
            onChange={(e) => setShowArchived(e.target.checked)}
            className="h-4 w-4 rounded border-slate-300 text-brand-600 focus:ring-brand-500"
          />
          Show archived
        </label>
      </div>

      {loading ? (
        <LoadingSpinner label="Loading classes…" />
      ) : loadError ? (
        <ErrorAlert message={loadError} onRetry={load} />
      ) : (
        <DataTable<ClassItem>
          ariaLabel="Classes"
          columns={[
            { key: 'name', header: 'Class', render: (r) => <span className="font-medium">{r.name}</span> },
            { key: 'section', header: 'Section', render: (r) => r.section },
            { key: 'subject', header: 'Subject', render: (r) => r.subject },
            { key: 'year', header: 'Academic year', render: (r) => r.academic_year },
            { key: 'students', header: 'Students', render: (r) => <span className="tabular-nums">{r.student_count}</span> },
            {
              key: 'status',
              header: 'Status',
              render: (r) =>
                r.status === 'archived' ? (
                  <span className="inline-flex rounded-full bg-slate-100 px-2.5 py-1 text-xs font-medium text-slate-600 ring-1 ring-inset ring-slate-600/10">
                    Archived
                  </span>
                ) : (
                  <span className="inline-flex rounded-full bg-emerald-100 px-2.5 py-1 text-xs font-medium text-emerald-800 ring-1 ring-inset ring-emerald-600/20">
                    Active
                  </span>
                ),
            },
            {
              key: 'actions',
              header: 'Actions',
              render: (r) => (
                <span className="flex flex-wrap gap-1.5">
                  <Button size="sm" variant="secondary" onClick={() => navigate(`/classes/${r.id}`)}>
                    View
                  </Button>
                  <Button size="sm" variant="secondary" onClick={() => openEdit(r)}>
                    Edit
                  </Button>
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
          ]}
          rows={visible}
          rowKey={(r) => r.id}
          emptyMessage="No classes yet. Create your first class to get started."
        />
      )}

      <Modal
        open={modalOpen}
        title={editing ? 'Edit class' : 'New class'}
        onClose={() => setModalOpen(false)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button loading={saving} onClick={onSave}>
              {editing ? 'Save changes' : 'Create class'}
            </Button>
          </>
        }
      >
        <form onSubmit={onSave} className="space-y-4" noValidate>
          <div>
            <label htmlFor="class-name" className="label">Class name</label>
            <input id="class-name" className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="e.g. Grade 5-A" />
            {formErrors.name && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.name}</p>}
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label htmlFor="class-section" className="label">Section</label>
              <input id="class-section" className="input" value={form.section} onChange={(e) => setForm({ ...form, section: e.target.value })} placeholder="e.g. A" />
              {formErrors.section && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.section}</p>}
            </div>
            <div>
              <label htmlFor="class-subject" className="label">Subject</label>
              <input id="class-subject" className="input" value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} placeholder="e.g. Mathematics" />
              {formErrors.subject && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.subject}</p>}
            </div>
          </div>
          <div>
            <label htmlFor="class-year" className="label">Academic year</label>
            <input id="class-year" className="input" value={form.academic_year} onChange={(e) => setForm({ ...form, academic_year: e.target.value })} placeholder="e.g. 2026-27" />
            {formErrors.academic_year && <p role="alert" className="mt-1 text-xs text-red-600">{formErrors.academic_year}</p>}
          </div>
        </form>
      </Modal>

      <Modal
        open={confirmArchive !== null}
        title={confirmArchive?.status === 'archived' ? 'Restore class' : 'Archive class'}
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
            ? `Restore “${confirmArchive?.name}” so it appears in active lists again?`
            : `Archive “${confirmArchive?.name}”? It will be hidden from active lists but kept with its students and sessions.`}
        </p>
      </Modal>
    </Layout>
  );
}
