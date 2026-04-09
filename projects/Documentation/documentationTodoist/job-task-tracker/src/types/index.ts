export type Priority = 'p1' | 'p2' | 'p3' | 'p4';

export interface SubTask {
  id: string;
  content: string;
  completed: boolean;
  createdAt: string;
}

export interface Comment {
  id: string;
  content: string;
  createdAt: string;
}

export interface Attachment {
  id: string;
  name: string;
  url: string;
  size: number;
  type: string;
  uploadedAt: string;
}

export interface Reminder {
  id: string;
  date: string;
  type: 'absolute' | 'relative';
}

export interface RecurringConfig {
  pattern: 'daily' | 'weekly' | 'monthly' | 'yearly' | 'custom';
  interval: number;
  daysOfWeek?: number[];
  dayOfMonth?: number;
  endDate?: string;
}

export interface Task {
  id: string;
  content: string;
  description?: string;
  priority: Priority;
  dueDate?: string;
  projectId: string;
  sectionId?: string;
  completed: boolean;
  completedAt?: string;
  createdAt: string;
  order: number;
  labels: string[];
  subTasks?: SubTask[];
  comments?: Comment[];
  attachments?: Attachment[];
  reminders?: Reminder[];
  recurring?: RecurringConfig;
  parentTaskId?: string;
}

export interface Section {
  id: string;
  name: string;
  projectId: string;
  order: number;
  collapsed: boolean;
}

export interface Label {
  id: string;
  name: string;
  color: string;
}

export interface Filter {
  id: string;
  name: string;
  query: string;
  color: string;
}

export interface ActivityLog {
  id: string;
  type: 'task_created' | 'task_completed' | 'task_updated' | 'project_created';
  description: string;
  timestamp: string;
  taskId?: string;
  projectId?: string;
}

export interface Project {
  id: string;
  name: string;
  color: string;
  icon?: string;
  order: number;
  isArchived: boolean;
  sections?: Section[];
  viewMode?: 'list' | 'board';
}

export interface AppState {
  tasks: Task[];
  projects: Project[];
  labels: Label[];
  filters: Filter[];
  sections: Section[];
  activityLog: ActivityLog[];
  theme: 'light' | 'dark';
  view: 'today' | 'upcoming' | 'inbox' | 'project' | 'filter' | 'completed';
  selectedProjectId?: string;
  selectedFilterId?: string;
  searchQuery: string;
  selectedTasks: string[];
  karmaPoints: number;
}