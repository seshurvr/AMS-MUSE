import { useState } from 'react';
import type { ReactNode } from 'react';
import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Button } from './Button';

const navItems = [
  {
    to: '/',
    label: 'Dashboard',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <rect x="2" y="2" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.5" />
        <rect x="10" y="2" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.5" />
        <rect x="2" y="10" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.5" />
        <rect x="10" y="10" width="6" height="6" rx="1.5" stroke="currentColor" strokeWidth="1.5" />
      </svg>
    ),
  },
  {
    to: '/classes',
    label: 'Classes',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <path d="M2.5 6.5L9 3l6.5 3.5L9 10 2.5 6.5z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
        <path d="M5 8v4.5L9 14.5l4-2V8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ),
  },
  {
    to: '/students',
    label: 'Students',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <circle cx="6.5" cy="6" r="3" stroke="currentColor" strokeWidth="1.5" />
        <path d="M1.5 15.5c.7-2.6 2.7-4 5-4s4.3 1.4 5 4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        <path d="M12.5 4.5v5M10 7h5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    to: '/attendance/new',
    label: 'Take Attendance',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <rect x="1.5" y="3.5" width="15" height="11" rx="2" stroke="currentColor" strokeWidth="1.5" />
        <circle cx="9" cy="8" r="2.2" stroke="currentColor" strokeWidth="1.5" />
        <path d="M5.5 12.5c.7-1.4 2-2.1 3.5-2.1s2.8.7 3.5 2.1" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    to: '/attendance/history',
    label: 'History',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <circle cx="9" cy="9" r="6.5" stroke="currentColor" strokeWidth="1.5" />
        <path d="M9 5.5V9l2.5 1.7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    to: '/reports',
    label: 'Reports',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <path d="M3 15.5V9.5M8 15.5v-9M13 15.5V4.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
    ),
  },
  {
    to: '/settings',
    label: 'Settings',
    icon: (
      <svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-hidden="true">
        <circle cx="9" cy="9" r="2.6" stroke="currentColor" strokeWidth="1.5" />
        <path d="M9 1.8v2.2M9 14v2.2M1.8 9h2.2M14 9h2.2M4 4l1.6 1.6M12.4 12.4L14 14M14 4l-1.6 1.6M5.6 12.4L4 14" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
      </svg>
    ),
  },
];

function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const { logout, user } = useAuth();
  return (
    <div className="flex h-full flex-col">
      <Link to="/" onClick={onNavigate} className="flex items-center gap-2.5 px-5 py-5">
        <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-brand-600 text-white" aria-hidden="true">
          <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
            <rect x="2" y="4" width="16" height="12" rx="2" stroke="currentColor" strokeWidth="1.8" />
            <circle cx="10" cy="8.6" r="2.2" stroke="currentColor" strokeWidth="1.6" />
            <path d="M6 13.4c.7-1.4 2.1-2.1 4-2.1s3.3.7 4 2.1" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
        </span>
        <span className="text-base font-bold text-slate-900">
          ClassSnap
          <span className="block text-[11px] font-medium text-slate-500">Photo Attendance</span>
        </span>
      </Link>
      <nav aria-label="Primary" className="flex-1 space-y-1 px-3">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            onClick={onNavigate}
            className={({ isActive }) =>
              `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-brand-50 text-brand-700'
                  : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
              }`
            }
          >
            {item.icon}
            {item.label}
          </NavLink>
        ))}
      </nav>
      <div className="border-t border-slate-200 p-4">
        <p className="truncate text-sm font-medium text-slate-900">{user?.username}</p>
        <p className="truncate text-xs text-slate-500">{user?.email}</p>
        <Button variant="ghost" size="sm" className="mt-2 w-full justify-start !px-0" onClick={logout}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
            <path d="M6 2.5H3.5v11H6M10.5 5.5L13 8l-2.5 2.5M13 8H6.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          Sign out
        </Button>
      </div>
    </div>
  );
}

export function Layout({ children, title }: { children: ReactNode; title: string }) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const navigate = useNavigate();
  const { user } = useAuth();

  return (
    <div className="min-h-screen">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-40 hidden w-64 border-r border-slate-200 bg-white lg:block">
        <SidebarContent />
      </aside>

      {/* Mobile drawer */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-slate-900/50" onClick={() => setMobileOpen(false)} aria-hidden="true" />
          <aside className="absolute inset-y-0 left-0 w-72 bg-white shadow-xl">
            <SidebarContent onNavigate={() => setMobileOpen(false)} />
          </aside>
        </div>
      )}

      <div className="lg:pl-64">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-slate-200 bg-white/95 px-4 backdrop-blur sm:px-6">
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            aria-label="Open navigation menu"
            className="btn-focus rounded-lg p-2 text-slate-600 hover:bg-slate-100 lg:hidden"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" aria-hidden="true">
              <path d="M3 5h14M3 10h14M3 15h14" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
            </svg>
          </button>
          <h1 className="text-lg font-semibold text-slate-900">{title}</h1>
          <div className="ml-auto flex items-center gap-2">
            <Button variant="primary" size="sm" onClick={() => navigate('/attendance/new')}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" aria-hidden="true">
                <rect x="1" y="2.5" width="12" height="9" rx="1.8" stroke="currentColor" strokeWidth="1.5" />
                <circle cx="7" cy="6.4" r="1.8" stroke="currentColor" strokeWidth="1.3" />
                <path d="M4 10c.5-1 1.6-1.6 3-1.6s2.5.6 3 1.6" stroke="currentColor" strokeWidth="1.3" strokeLinecap="round" />
              </svg>
              Take Attendance
            </Button>
            <span
              className="hidden h-8 w-8 items-center justify-center rounded-full bg-brand-100 text-sm font-semibold text-brand-700 sm:flex"
              title={user?.username}
              aria-label={`Signed in as ${user?.username}`}
            >
              {(user?.username ?? '?').slice(0, 1).toUpperCase()}
            </span>
          </div>
        </header>
        <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">{children}</main>
      </div>
    </div>
  );
}
