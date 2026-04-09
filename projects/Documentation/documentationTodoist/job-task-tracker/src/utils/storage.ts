import { Task, Project, AppState } from '../types';

const STORAGE_KEY = 'job-task-tracker-data';

export const loadState = (): Partial<AppState> | null => {
  try {
    const serialized = localStorage.getItem(STORAGE_KEY);
    if (serialized === null) return null;
    return JSON.parse(serialized);
  } catch (err) {
    console.error('Error loading state:', err);
    return null;
  }
};

export const saveState = (state: Partial<AppState>): void => {
  try {
    const serialized = JSON.stringify(state);
    localStorage.setItem(STORAGE_KEY, serialized);
  } catch (err) {
    console.error('Error saving state:', err);
  }
};

export const exportData = (tasks: Task[], projects: Project[]): string => {
  return JSON.stringify({ tasks, projects, exportDate: new Date().toISOString() }, null, 2);
};

export const exportToCSV = (tasks: Task[]): string => {
  const headers = ['Content', 'Priority', 'Due Date', 'Completed', 'Created At', 'Description'];
  const rows = tasks.map(task => [
    task.content,
    task.priority.toUpperCase(),
    task.dueDate || '',
    task.completed ? 'Yes' : 'No',
    task.createdAt,
    task.description || ''
  ]);
  
  const csvContent = [
    headers.join(','),
    ...rows.map(row => row.map(cell => `"${cell}"`).join(','))
  ].join('\n');
  
  return csvContent;
};