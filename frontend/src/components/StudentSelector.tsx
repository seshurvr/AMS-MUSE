import { useEffect, useMemo, useRef, useState } from 'react';
import type { Student } from '../services/api';

interface StudentSelectorProps {
  students: Student[];
  value: number | null; // student id
  onChange: (studentId: number | null) => void;
  placeholder?: string;
  disabled?: boolean;
  label: string;
  /** ids of other detections' mapped students, to visually flag duplicates */
  takenStudentIds?: Set<number>;
}

/**
 * Searchable dropdown for mapping a detection box to a student.
 * The teacher confirms each mapping manually — the system never identifies faces.
 */
export function StudentSelector({
  students,
  value,
  onChange,
  placeholder = 'Select student…',
  disabled = false,
  label,
  takenStudentIds,
}: StudentSelectorProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [highlight, setHighlight] = useState(0);
  const rootRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const listId = useRef(`ss-${Math.random().toString(36).slice(2, 9)}`).current;

  const active = useMemo(() => students.filter((s) => s.status !== 'archived'), [students]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return active;
    return active.filter(
      (s) =>
        s.name.toLowerCase().includes(q) ||
        s.roll_number.toLowerCase().includes(q) ||
        s.student_id.toLowerCase().includes(q),
    );
  }, [active, query]);

  const selected = value != null ? students.find((s) => s.id === value) ?? null : null;

  useEffect(() => {
    if (!open) return;
    const onDoc = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDoc);
    return () => document.removeEventListener('mousedown', onDoc);
  }, [open ]);

  useEffect(() => setHighlight(0), [query]);

  const choose = (id: number | null) => {
    onChange(id);
    setOpen(false);
    setQuery('');
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setOpen(true);
      setHighlight((h) => Math.min(h + 1, filtered.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setHighlight((h) => Math.max(h - 1, 0));
    } else if (e.key === 'Enter' && open && filtered[highlight]) {
      e.preventDefault();
      choose(filtered[highlight].id);
    } else if (e.key === 'Escape') {
      setOpen(false);
    }
  };

  return (
    <div ref={rootRef} className="relative">
      <span id={`${listId}-label`} className="sr-only">
        {label}
      </span>
      <div
        className={`flex items-center rounded-lg border bg-white shadow-sm transition-colors ${
          open ? 'border-brand-500 ring-2 ring-brand-200' : 'border-slate-300'
        } ${disabled ? 'bg-slate-50 opacity-60' : ''}`}
      >
        <input
          ref={inputRef}
          type="text"
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          aria-labelledby={`${listId}-label`}
          aria-activedescendant={open && filtered[highlight] ? `${listId}-opt-${filtered[highlight].id}` : undefined}
          value={open ? query : selected ? `${selected.name} (${selected.roll_number})` : ''}
          placeholder={placeholder}
          disabled={disabled}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={onKeyDown}
          className="w-full rounded-lg bg-transparent px-3 py-2 text-sm text-slate-900 placeholder-slate-400 focus:outline-none"
        />
        {selected && !disabled && (
          <button
            type="button"
            aria-label="Clear selection"
            onClick={() => choose(null)}
            className="btn-focus mr-1 rounded p-1 text-slate-400 hover:text-slate-600"
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
              <path d="M3.5 3.5l7 7M10.5 3.5l-7 7" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
            </svg>
          </button>
        )}
        <span className="pointer-events-none pr-2 text-slate-400" aria-hidden="true">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M3.5 5.5L7 9l3.5-3.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </span>
      </div>

      {open && !disabled && (
        <ul
          id={listId}
          role="listbox"
          aria-labelledby={`${listId}-label`}
          className="absolute z-30 mt-1 max-h-56 w-full overflow-y-auto rounded-lg border border-slate-200 bg-white py-1 shadow-lg"
        >
          {filtered.length === 0 ? (
            <li className="px-3 py-2 text-sm text-slate-500">No students match “{query}”.</li>
          ) : (
            filtered.map((s, i) => {
              const taken = takenStudentIds?.has(s.id) && s.id !== value;
              return (
                <li
                  key={s.id}
                  id={`${listId}-opt-${s.id}`}
                  role="option"
                  aria-selected={s.id === value}
                  onMouseDown={(e) => {
                    e.preventDefault();
                    choose(s.id);
                  }}
                  onMouseEnter={() => setHighlight(i)}
                  className={`cursor-pointer px-3 py-2 text-sm ${
                    i === highlight ? 'bg-brand-50' : ''
                  } ${s.id === value ? 'font-semibold text-brand-700' : 'text-slate-900'}`}
                >
                  <span className="flex items-center justify-between gap-2">
                    <span>
                      {s.name}{' '}
                      <span className="text-xs text-slate-500">
                        Roll {s.roll_number} · {s.student_id}
                      </span>
                    </span>
                    {taken && (
                      <span className="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-semibold text-amber-800">
                        Mapped elsewhere
                      </span>
                    )}
                  </span>
                </li>
              );
            })
          )}
        </ul>
      )}
    </div>
  );
}
