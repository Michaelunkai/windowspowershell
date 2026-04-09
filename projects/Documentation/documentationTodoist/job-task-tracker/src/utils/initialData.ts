import { Task, Project, Label, Filter, Section, ActivityLog } from '../types';

export const initialProjects: Project[] = [
  { id: 'inbox', name: 'Inbox', color: '#3b82f6', order: 0, isArchived: false, viewMode: 'list' },
  { id: 'documentation', name: 'Documentation (Job)', color: '#10b981', order: 1, isArchived: false, viewMode: 'list', sections: [] },
  { id: 'meetings', name: 'Meetings', color: '#f59e0b', order: 2, isArchived: false, viewMode: 'list', sections: [] },
  { id: 'development', name: 'Development', color: '#8b5cf6', order: 3, isArchived: false, viewMode: 'list', sections: [] },
  { id: 'admin', name: 'Administrative', color: '#ef4444', order: 4, isArchived: false, viewMode: 'list', sections: [] },
];

export const initialLabels: Label[] = [
  { id: 'label-database', name: 'database', color: '#3b82f6' },
  { id: 'label-infrastructure', name: 'infrastructure', color: '#10b981' },
  { id: 'label-bugfix', name: 'bugfix', color: '#ef4444' },
  { id: 'label-production', name: 'production', color: '#f59e0b' },
  { id: 'label-staging', name: 'staging', color: '#8b5cf6' },
  { id: 'label-docker', name: 'docker', color: '#06b6d4' },
  { id: 'label-task', name: 'task', color: '#6366f1' },
];

export const initialFilters: Filter[] = [
  { id: 'filter-priority', name: 'High Priority', query: 'p1', color: '#ef4444' },
  { id: 'filter-thisweek', name: 'This Week', query: 'thisweek', color: '#10b981' },
  { id: 'filter-overdue', name: 'Overdue', query: 'overdue', color: '#f59e0b' },
];

export const initialSections: Section[] = [];

export const initialActivityLog: ActivityLog[] = [];

export const initialTasks: Task[] = [
  {
    id: '1',
    content: 'SUM 23 12 25',
    description: 'i used alex diagnostics and made my own deep diagnostics of DB problems ...',
    priority: 'p2',
    dueDate: '2025-12-23',
    projectId: 'documentation',
    completed: false,
    createdAt: '2025-12-23T00:00:00.000Z',
    order: 0,
    labels: ['database']
  },
  {
    id: '2',
    content: 'SUM 24 12 25',
    description: 'Database...',
    priority: 'p2',
    dueDate: '2025-12-24',
    projectId: 'documentation',
    completed: false,
    createdAt: '2025-12-24T00:00:00.000Z',
    order: 1,
    labels: ['database']
  },
  {
    id: '3',
    content: 'sum 25 12 25',
    description: 'Dec 25 - TovPlay Infrastructure...',
    priority: 'p2',
    dueDate: '2025-12-25',
    projectId: 'documentation',
    completed: false,
    createdAt: '2025-12-25T00:00:00.000Z',
    order: 2,
    labels: ['infrastructure']
  },
  {
    id: '4',
    content: 'sum 29 12 25',
    description: 'Fixed the broken daily backup script on production. The original had hardcoded timestamps and empty file paths, making it non-function...',
    priority: 'p1',
    dueDate: '2025-12-29',
    projectId: 'documentation',
    completed: false,
    createdAt: '2025-12-29T00:00:00.000Z',
    order: 3,
    labels: ['bugfix', 'production']
  },
  {
    id: '5',
    content: 'sum 30 12 25',
    description: 'summey for itamar converted for macos...',
    priority: 'p2',
    dueDate: '2025-12-30',
    projectId: 'documentation',
    completed: false,
    createdAt: '2025-12-30T00:00:00.000Z',
    order: 4,
    labels: ['task']
  },
  {
    id: '6',
    content: 'sum 31 12 25',
    description: 'Staging Backend Crash Loop - Fixed staging backend crash loop (exit 255) caused by CRLF line endings in docker-entrypoint.sh. Extracted...',
    priority: 'p1',
    dueDate: '2025-12-31',
    projectId: 'documentation',
    completed: false,
    createdAt: '2025-12-31T00:00:00.000Z',
    order: 5,
    labels: ['bugfix', 'staging', 'docker']
  }
];