import type { SessionSummary } from '../services/api';
import { AttendanceStatusBadge } from './AttendanceStatusBadge';

interface AttendanceSummaryProps {
  summary: SessionSummary;
}

/** Counts + percentage bar for a session summary. */
export function AttendanceSummary({ summary }: AttendanceSummaryProps) {
  const pct = Math.round(summary.attendance_percentage);
  return (
    <div className="card p-4" aria-label="Attendance summary">
      <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Present</p>
          <p className="text-2xl font-bold text-emerald-700">{summary.present}</p>
        </div>
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Absent</p>
          <p className="text-2xl font-bold text-red-700">{summary.absent}</p>
        </div>
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Excused</p>
          <p className="text-2xl font-bold text-sky-700">{summary.excused}</p>
        </div>
        <div>
          <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Needs review</p>
          <p className="text-2xl font-bold text-amber-700">{summary.needs_review}</p>
        </div>
        <div className="ml-auto text-right">
          <p className="text-xs font-medium uppercase tracking-wide text-slate-500">Attendance</p>
          <p className="text-2xl font-bold text-slate-900">{pct}%</p>
        </div>
      </div>
      <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-slate-100" role="img" aria-label={`Attendance ${pct} percent`}>
        <div className="h-full rounded-full bg-brand-600 transition-all" style={{ width: `${pct}%` }} />
      </div>
      <div className="mt-3 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-3 text-xs text-slate-600">
        <span className="mr-1 font-medium">Detected on photo: {summary.detected} of {summary.total}</span>
        <AttendanceStatusBadge status="present" size="sm" />
        <span>= {summary.present}</span>
        <AttendanceStatusBadge status="absent" size="sm" />
        <span>= {summary.absent}</span>
        <AttendanceStatusBadge status="excused" size="sm" />
        <span>= {summary.excused}</span>
        <AttendanceStatusBadge status="needs_review" size="sm" />
        <span>= {summary.needs_review}</span>
      </div>
    </div>
  );
}
