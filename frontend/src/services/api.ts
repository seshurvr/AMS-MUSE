// API client for the Classroom Photo Attendance Management System backend.
// Same-origin base path; in dev, Vite proxies /api -> http://localhost:8000.

export const TOKEN_KEY = 'cpams_token';

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
    this.name = 'ApiError';
  }
}

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

function redirectToLogin(): void {
  clearToken();
  if (window.location.pathname !== '/login') {
    window.location.href = '/login';
  }
}

async function parseError(res: Response): Promise<string> {
  try {
    const data = await res.json();
    if (typeof data === 'object' && data !== null) {
      if (typeof data.detail === 'string') return data.detail;
      if (typeof data.message === 'string') return data.message;
      if (typeof data.error === 'string') return data.error;
    }
    return `Request failed with status ${res.status}`;
  } catch {
    return `Request failed with status ${res.status}`;
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  const token = getToken();
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (init.body && typeof init.body === 'string' && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const res = await fetch(path, { ...init, headers });
  if (res.status === 401) {
    redirectToLogin();
    throw new ApiError(401, 'Your session has expired. Please sign in again.');
  }
  if (!res.ok) {
    throw new ApiError(res.status, await parseError(res));
  }
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

export async function apiGet<T>(path: string): Promise<T> {
  return request<T>(path, { method: 'GET' });
}

export async function apiPost<T>(path: string, body?: unknown): Promise<T> {
  return request<T>(path, {
    method: 'POST',
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

export async function apiPut<T>(path: string, body?: unknown): Promise<T> {
  return request<T>(path, {
    method: 'PUT',
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

export async function apiDelete<T = void>(path: string): Promise<T> {
  return request<T>(path, { method: 'DELETE' });
}

export async function apiUpload<T>(path: string, file: File, fieldName = 'file'): Promise<T> {
  const form = new FormData();
  form.append(fieldName, file);
  return request<T>(path, { method: 'POST', body: form });
}

/** GET a blob (e.g. CSV/XLSX downloads) and trigger a browser download. */
export async function apiDownload(path: string, filename: string): Promise<void> {
  const token = getToken();
  const headers = new Headers();
  if (token) headers.set('Authorization', `Bearer ${token}`);
  const res = await fetch(path, { headers });
  if (res.status === 401) {
    redirectToLogin();
    throw new ApiError(401, 'Your session has expired. Please sign in again.');
  }
  if (!res.ok) {
    throw new ApiError(res.status, await parseError(res));
  }
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}

// ---------------------------------------------------------------------------
// Domain types (match backend contract)
// ---------------------------------------------------------------------------

export type AttendanceStatus = 'present' | 'absent' | 'excused' | 'needs_review';

export interface User {
  id: number;
  username: string;
  email: string;
  role: string;
}

export interface LoginResponse {
  access_token: string;
  token_type: string;
  user: User;
}

export interface ClassItem {
  id: number;
  name: string;
  section: string;
  subject: string;
  academic_year: string;
  student_count: number;
  status: string;
}

export interface Student {
  id: number;
  student_id: string;
  roll_number: string;
  name: string;
  email?: string | null;
  status: string;
}

export interface ClassDetail {
  id: number;
  name: string;
  section: string;
  subject: string;
  academic_year: string;
  status: string;
  students: Student[];
}

export interface ImageQuality {
  width: number;
  height: number;
  brightness: number;
  blur_score: number;
  warnings: string[];
}

export interface ImageUploadResult {
  image_url: string;
  quality: ImageQuality;
}

export interface Detection {
  id: number;
  detection_number: number;
  x: number;
  y: number;
  width: number;
  height: number;
  confidence: number;
}

export interface ProcessResult {
  detections: Detection[];
  count: number;
}

export interface AttendanceRecord {
  student_id: number;
  status: AttendanceStatus;
  detection_id?: number | null;
  manually_confirmed: boolean;
  notes?: string | null;
}

export interface SessionInfo {
  id: number;
  class_id: number;
  class_name?: string;
  date: string;
  session_time: string;
  subject: string;
  notes?: string | null;
  status?: string;
  created_at?: string;
}

export interface SessionSummary {
  total: number;
  detected: number;
  present: number;
  absent: number;
  excused: number;
  needs_review: number;
  attendance_percentage: number;
}

export interface SessionDetail {
  session: SessionInfo;
  detections: Detection[];
  records: AttendanceRecord[];
  image_url: string;
  summary: SessionSummary;
}

export interface HistoryItem {
  id: number;
  date: string;
  session_time: string;
  class_name: string;
  section: string;
  subject: string;
  total: number;
  present: number;
  absent: number;
  excused: number;
  needs_review: number;
  status: string;
}

export interface ReportStudentRow {
  student_id: number;
  roll_number: string;
  name: string;
  total_sessions: number;
  present: number;
  absent: number;
  excused: number;
  needs_review: number;
  attendance_percentage: number;
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

export const authApi = {
  login(username: string, password: string): Promise<LoginResponse> {
    return apiPost<LoginResponse>('/api/auth/login', { username, password });
  },
  me(): Promise<User> {
    return apiGet<User>('/api/auth/me');
  },
  changePassword(current_password: string, new_password: string): Promise<void> {
    return apiPut<void>('/api/auth/password', { current_password, new_password });
  },
};

// ---------------------------------------------------------------------------
// Classes
// ---------------------------------------------------------------------------

export const classesApi = {
  list(): Promise<ClassItem[]> {
    return apiGet<ClassItem[]>('/api/classes');
  },
  get(id: number): Promise<ClassDetail> {
    return apiGet<ClassDetail>(`/api/classes/${id}`);
  },
  create(data: {
    name: string;
    section: string;
    subject: string;
    academic_year: string;
  }): Promise<ClassDetail> {
    return apiPost<ClassDetail>('/api/classes', data);
  },
  update(id: number, data: Partial<{ name: string; section: string; subject: string; academic_year: string; status: string }>): Promise<ClassDetail> {
    return apiPut<ClassDetail>(`/api/classes/${id}`, data);
  },
  remove(id: number): Promise<void> {
    return apiDelete(`/api/classes/${id}`);
  },
  students(id: number): Promise<Student[]> {
    return apiGet<Student[]>(`/api/classes/${id}/students`);
  },
  importStudents(id: number, file: File): Promise<{ imported: number; skipped?: number; errors?: string[] }> {
    return apiUpload(`/api/classes/${id}/students/import`, file);
  },
  exportStudents(id: number): Promise<void> {
    return apiDownload(`/api/classes/${id}/students/export?format=csv`, 'students.csv');
  },
};

// ---------------------------------------------------------------------------
// Students
// ---------------------------------------------------------------------------

export const studentsApi = {
  create(data: { class_id: number; student_id: string; roll_number: string; name: string; email?: string }): Promise<Student> {
    return apiPost<Student>('/api/students', data);
  },
  update(id: number, data: Partial<{ student_id: string; roll_number: string; name: string; email?: string | null; status: string }>): Promise<Student> {
    return apiPut<Student>(`/api/students/${id}`, data);
  },
  remove(id: number): Promise<void> {
    return apiDelete(`/api/students/${id}`);
  },
};

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------

export const attendanceApi = {
  createSession(data: {
    class_id: number;
    date: string;
    session_time: string;
    subject: string;
    notes?: string;
  }): Promise<SessionInfo> {
    return apiPost<SessionInfo>('/api/attendance/sessions', data);
  },
  uploadImage(sessionId: number, file: File): Promise<ImageUploadResult> {
    return apiUpload<ImageUploadResult>(`/api/attendance/sessions/${sessionId}/image`, file, 'image');
  },
  processImage(sessionId: number): Promise<ProcessResult> {
    return apiPost<ProcessResult>(`/api/attendance/sessions/${sessionId}/process`);
  },
  getSession(sessionId: number): Promise<SessionDetail> {
    return apiGet<SessionDetail>(`/api/attendance/sessions/${sessionId}`);
  },
  saveRecords(sessionId: number, records: AttendanceRecord[]): Promise<SessionDetail> {
    return apiPut<SessionDetail>(`/api/attendance/sessions/${sessionId}/records`, { records });
  },
  finalize(sessionId: number, records?: AttendanceRecord[]): Promise<{ ok: boolean; summary: SessionSummary }> {
    return apiPost<{ ok: boolean; summary: SessionSummary }>(
      `/api/attendance/sessions/${sessionId}/finalize`,
      records ? { records } : {},
    );
  },
  deleteSession(sessionId: number): Promise<void> {
    return apiDelete(`/api/attendance/sessions/${sessionId}`);
  },
  history(params: { class_id?: number | ''; from?: string; to?: string }): Promise<HistoryItem[]> {
    const q = new URLSearchParams();
    if (params.class_id) q.set('class_id', String(params.class_id));
    if (params.from) q.set('from', params.from);
    if (params.to) q.set('to', params.to);
    const qs = q.toString();
    return apiGet<HistoryItem[]>(`/api/attendance/history${qs ? `?${qs}` : ''}`);
  },
};

// ---------------------------------------------------------------------------
// Reports & export
// ---------------------------------------------------------------------------

export const reportsApi = {
  summary(params: { class_id?: number | ''; from?: string; to?: string }): Promise<{ students: ReportStudentRow[] }> {
    const q = new URLSearchParams();
    if (params.class_id) q.set('class_id', String(params.class_id));
    if (params.from) q.set('from', params.from);
    if (params.to) q.set('to', params.to);
    const qs = q.toString();
    return apiGet<{ students: ReportStudentRow[] }>(`/api/reports/summary${qs ? `?${qs}` : ''}`);
  },
  exportAttendance(sessionId: number, format: 'csv' | 'xlsx'): Promise<void> {
    return apiDownload(`/api/export/attendance?session_id=${sessionId}&format=${format}`, `attendance-session-${sessionId}.${format}`);
  },
};
