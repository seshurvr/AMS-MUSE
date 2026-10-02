import type { ReactNode } from 'react';
import type { AttendanceStatus } from '../services/api';

const config: Record<AttendanceStatus, { label: string; classes: string; icon: ReactNode }> = {
  present: {
    label: 'Present',
    classes: 'bg-emerald-100 text-emerald-800 ring-emerald-600/20',
    icon: (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
        <path d="M2.5 6.5l2.5 2.5 4.5-5.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ),
  },
  absent: {
    label: 'Absent',
    classes: 'bg-red-100 text-red-800 ring-red-600/20',
    icon: (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
        <path d="M3 3l6 6M9 3l-6 6" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    ),
  },
  excused: {
    label: 'Excused',
    classes: 'bg-sky-100 text-sky-800 ring-sky-600/20',
    icon: (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
        <circle cx="6" cy="6" r="4.6" stroke="currentColor" strokeWidth="1.6" />
        <path d="M6 3.6V6l1.6 1.2" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
      </svg>
    ),
  },
  needs_review: {
    label: 'Needs review',
    classes: 'bg-amber-100 text-amber-900 ring-amber-600/25',
    icon: (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true">
        <path d="M6 1.8L11 10H1L6 1.8z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
        <path d="M6 4.6v2.2M6 8.6v.1" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    ),
  },
};

export function AttendanceStatusBadge({ status, size = 'md' }: { status: AttendanceStatus; size?: 'sm' | 'md' }) {
  const c = config[status];
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full font-medium ring-1 ring-inset ${c.classes} ${
        size === 'sm' ? 'px-2 py-0.5 text-[11px]' : 'px-2.5 py-1 text-xs'
      }`}
      aria-label={`Attendance status: ${c.label}`}
    >
      <span aria-hidden="true">{c.icon}</span>
      {c.label}
    </span>
  );
}
