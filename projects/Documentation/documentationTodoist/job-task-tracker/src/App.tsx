import { useState, useEffect, useMemo } from 'react';
import { Task, Project, AppState, Priority, Label, Filter, Section, SubTask, Comment } from './types';
import { loadState, saveState, exportData, exportToCSV } from './utils/storage';
import { initialTasks, initialProjects, initialLabels, initialFilters, initialSections, initialActivityLog } from './utils/initialData';
import { Plus, Search, Sun, Moon, Calendar, Inbox, BarChart3, Download, Check, Trash2, CheckCircle, FileText, Filter as FilterIcon, Tag, MessageSquare, Paperclip, Bell, Repeat, ChevronDown, ChevronRight, Edit2, Save, X, MoreVertical, Archive, Star, CheckSquare } from 'lucide-react';
import { format, isToday, isPast, parseISO, isThisWeek } from 'date-fns';

const priorityColors = { p1: 'text-red-600 border-red-600 bg-red-50 dark:bg-red-900/20', p2: 'text-orange-600 border-orange-600 bg-orange-50 dark:bg-orange-900/20', p3: 'text-blue-600 border-blue-600 bg-blue-50 dark:bg-blue-900/20', p4: 'text-gray-600 border-gray-600 bg-gray-50 dark:bg-gray-900/20' };

function App() {
  const [state, setState] = useState<AppState>(() => {
    const saved = loadState();
    return {
      tasks: saved?.tasks || initialTasks,
      projects: saved?.projects || initialProjects,
      labels: saved?.labels || initialLabels,
      filters: saved?.filters || initialFilters,
      sections: saved?.sections || initialSections,
      activityLog: saved?.activityLog || initialActivityLog,
      theme: (saved?.theme as 'light' | 'dark') || 'light',
      view: 'project' as const,
      selectedProjectId: saved?.selectedProjectId || 'documentation',
      selectedFilterId: undefined,
      searchQuery: '',
      selectedTasks: [],
      karmaPoints: saved?.karmaPoints || 0
    };
  });

  const [newTaskContent, setNewTaskContent] = useState('');
  const [newTaskPriority, setNewTaskPriority] = useState<Priority>('p2');
  const [newTaskDate, setNewTaskDate] = useState(new Date().toISOString().split('T')[0]);
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);
  const [editingContent, setEditingContent] = useState('');
  const [editingDescription, setEditingDescription] = useState('');
  const [editingPriority, setEditingPriority] = useState<Priority>('p2');
  const [editingDate, setEditingDate] = useState('');
  const [editingProjectId, setEditingProjectId] = useState('');
  const [expandedTasks, setExpandedTasks] = useState<Set<string>>(new Set());
  const [showTaskDetails, setShowTaskDetails] = useState<string | null>(null);
  const [newSubTaskContent, setNewSubTaskContent] = useState('');
  const [newCommentContent, setNewCommentContent] = useState('');
  const [selectedLabels, setSelectedLabels] = useState<string[]>([]);
  const [showBulkActions, setShowBulkActions] = useState(false);

  useEffect(() => { saveState(state); }, [state]);
  useEffect(() => { document.documentElement.classList.toggle('dark', state.theme === 'dark'); }, [state.theme]);

  const addActivity = (type: 'task_created' | 'task_completed' | 'task_updated' | 'project_created', description: string, taskId?: string, projectId?: string) => {
    const activity = {
      id: Date.now().toString(),
      type,
      description,
      timestamp: new Date().toISOString(),
      taskId,
      projectId
    };
    setState(prev => ({ ...prev, activityLog: [activity, ...prev.activityLog].slice(0, 100) }));
  };

  const addTask = () => {
    if (!newTaskContent.trim()) return;
    const newTask: Task = {
      id: Date.now().toString(),
      content: newTaskContent,
      priority: newTaskPriority,
      dueDate: newTaskDate,
      projectId: state.selectedProjectId || 'inbox',
      completed: false,
      createdAt: new Date().toISOString(),
      order: state.tasks.length,
      labels: selectedLabels,
      subTasks: [],
      comments: [],
      attachments: [],
      reminders: []
    };
    setState(prev => ({ ...prev, tasks: [...prev.tasks, newTask], karmaPoints: prev.karmaPoints + 5 }));
    addActivity('task_created', `Created task: ${newTaskContent}`, newTask.id);
    setNewTaskContent('');
    setSelectedLabels([]);
  };

  const toggleTask = (id: string) => {
    setState(prev => {
      const task = prev.tasks.find(t => t.id === id);
      const newCompleted = !task?.completed;
      return {
        ...prev,
        tasks: prev.tasks.map(t => t.id === id ? { ...t, completed: newCompleted, completedAt: newCompleted ? new Date().toISOString() : undefined } : t),
        karmaPoints: newCompleted ? prev.karmaPoints + 10 : prev.karmaPoints - 10
      };
    });
    const task = state.tasks.find(t => t.id === id);
    if (task) {
      addActivity('task_completed', `${task.completed ? 'Uncompleted' : 'Completed'} task: ${task.content}`, id);
    }
  };

  const deleteTask = (id: string) => {
    const task = state.tasks.find(t => t.id === id);
    setState(prev => ({ ...prev, tasks: prev.tasks.filter(t => t.id !== id) }));
    if (task) {
      addActivity('task_updated', `Deleted task: ${task.content}`);
    }
  };

  const startEditingTask = (task: Task) => {
    setEditingTaskId(task.id);
    setEditingContent(task.content);
    setEditingDescription(task.description || '');
    setEditingPriority(task.priority);
    setEditingDate(task.dueDate || '');
    setEditingProjectId(task.projectId);
  };

  const saveTaskEdit = () => {
    if (!editingTaskId) return;
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.map(t =>
        t.id === editingTaskId
          ? {
              ...t,
              content: editingContent,
              description: editingDescription,
              priority: editingPriority,
              dueDate: editingDate,
              projectId: editingProjectId
            }
          : t
      )
    }));
    addActivity('task_updated', `Updated task: ${editingContent}`, editingTaskId);
    setEditingTaskId(null);
  };

  const cancelEdit = () => {
    setEditingTaskId(null);
  };

  const addSubTask = (taskId: string) => {
    if (!newSubTaskContent.trim()) return;
    const subTask: SubTask = {
      id: Date.now().toString(),
      content: newSubTaskContent,
      completed: false,
      createdAt: new Date().toISOString()
    };
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.map(t =>
        t.id === taskId
          ? { ...t, subTasks: [...(t.subTasks || []), subTask] }
          : t
      )
    }));
    setNewSubTaskContent('');
  };

  const toggleSubTask = (taskId: string, subTaskId: string) => {
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.map(t =>
        t.id === taskId
          ? {
              ...t,
              subTasks: t.subTasks?.map(st =>
                st.id === subTaskId ? { ...st, completed: !st.completed } : st
              )
            }
          : t
      )
    }));
  };

  const addComment = (taskId: string) => {
    if (!newCommentContent.trim()) return;
    const comment: Comment = {
      id: Date.now().toString(),
      content: newCommentContent,
      createdAt: new Date().toISOString()
    };
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.map(t =>
        t.id === taskId
          ? { ...t, comments: [...(t.comments || []), comment] }
          : t
      )
    }));
    setNewCommentContent('');
  };

  const toggleTaskSelection = (taskId: string) => {
    setState(prev => ({
      ...prev,
      selectedTasks: prev.selectedTasks.includes(taskId)
        ? prev.selectedTasks.filter(id => id !== taskId)
        : [...prev.selectedTasks, taskId]
    }));
  };

  const bulkComplete = () => {
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.map(t =>
        prev.selectedTasks.includes(t.id) ? { ...t, completed: true, completedAt: new Date().toISOString() } : t
      ),
      selectedTasks: [],
      karmaPoints: prev.karmaPoints + (prev.selectedTasks.length * 10)
    }));
    setShowBulkActions(false);
  };

  const bulkDelete = () => {
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.filter(t => !prev.selectedTasks.includes(t.id)),
      selectedTasks: []
    }));
    setShowBulkActions(false);
  };

  const bulkMove = (projectId: string) => {
    setState(prev => ({
      ...prev,
      tasks: prev.tasks.map(t =>
        prev.selectedTasks.includes(t.id) ? { ...t, projectId } : t
      ),
      selectedTasks: []
    }));
    setShowBulkActions(false);
  };

  const handleExport = (format: 'json' | 'csv') => {
    const data = format === 'json' ? exportData(state.tasks, state.projects) : exportToCSV(state.tasks);
    const blob = new Blob([data], { type: format === 'json' ? 'application/json' : 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tasks-export-${new Date().toISOString().split('T')[0]}.${format}`;
    a.click();
  };

  const filteredTasks = useMemo(() => {
    let filtered = state.tasks;

    // Filter by completion status
    if (state.view === 'completed') {
      filtered = filtered.filter(t => t.completed);
    } else {
      filtered = filtered.filter(t => !t.completed);
    }

    // Search query
    if (state.searchQuery) {
      filtered = filtered.filter(t =>
        t.content.toLowerCase().includes(state.searchQuery.toLowerCase()) ||
        t.description?.toLowerCase().includes(state.searchQuery.toLowerCase())
      );
    }

    // View filters
    if (state.view === 'today') {
      filtered = filtered.filter(t => t.dueDate && isToday(parseISO(t.dueDate)));
    } else if (state.view === 'upcoming') {
      filtered = filtered.filter(t => t.dueDate && !isPast(parseISO(t.dueDate)));
    } else if (state.view === 'inbox') {
      filtered = filtered.filter(t => t.projectId === 'inbox');
    } else if (state.view === 'project' && state.selectedProjectId) {
      filtered = filtered.filter(t => t.projectId === state.selectedProjectId);
    } else if (state.view === 'filter' && state.selectedFilterId) {
      const filter = state.filters.find(f => f.id === state.selectedFilterId);
      if (filter) {
        if (filter.query === 'p1') filtered = filtered.filter(t => t.priority === 'p1');
        else if (filter.query === 'thisweek') filtered = filtered.filter(t => t.dueDate && isThisWeek(parseISO(t.dueDate)));
        else if (filter.query === 'overdue') filtered = filtered.filter(t => t.dueDate && isPast(parseISO(t.dueDate)) && !t.completed);
      }
    }

    return filtered.sort((a, b) => a.order - b.order);
  }, [state.tasks, state.view, state.selectedProjectId, state.selectedFilterId, state.searchQuery]);

  const currentProject = state.projects.find(p => p.id === state.selectedProjectId);
  const stats = useMemo(() => ({
    total: state.tasks.length,
    completed: state.tasks.filter(t => t.completed).length,
    pending: state.tasks.filter(t => !t.completed).length,
    overdue: state.tasks.filter(t => !t.completed && t.dueDate && isPast(parseISO(t.dueDate))).length
  }), [state.tasks]);

  return (
    <div className="flex h-screen bg-gray-50 dark:bg-gray-900">
      {/* Sidebar */}
      <aside className="w-64 bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 flex flex-col">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <h1 className="text-xl font-bold text-gray-800 dark:text-white flex items-center gap-2">
            <CheckCircle className="w-6 h-6 text-primary-600" />
            Job Task Tracker
          </h1>
          <div className="mt-2 flex items-center gap-2 text-sm">
            <Star className="w-4 h-4 text-yellow-500" />
            <span className="text-gray-600 dark:text-gray-400">Karma: {state.karmaPoints}</span>
          </div>
        </div>

        <nav className="flex-1 p-3 overflow-y-auto">
          {/* Main Views */}
          <button onClick={() => setState(prev => ({ ...prev, view: 'inbox', selectedProjectId: 'inbox' }))} className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-1 ${state.view === 'inbox' ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}>
            <Inbox className="w-5 h-5" />
            <span>Inbox</span>
            <span className="ml-auto text-xs text-gray-500">{state.tasks.filter(t => t.projectId === 'inbox' && !t.completed).length}</span>
          </button>

          <button onClick={() => setState(prev => ({ ...prev, view: 'today' }))} className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-1 ${state.view === 'today' ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}>
            <Calendar className="w-5 h-5" />
            <span>Today</span>
            <span className="ml-auto text-xs text-gray-500">{state.tasks.filter(t => !t.completed && t.dueDate && isToday(parseISO(t.dueDate))).length}</span>
          </button>

          <button onClick={() => setState(prev => ({ ...prev, view: 'upcoming' }))} className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-1 ${state.view === 'upcoming' ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}>
            <FileText className="w-5 h-5" />
            <span>Upcoming</span>
            <span className="ml-auto text-xs text-gray-500">{state.tasks.filter(t => !t.completed && t.dueDate && !isPast(parseISO(t.dueDate))).length}</span>
          </button>

          <button onClick={() => setState(prev => ({ ...prev, view: 'completed' }))} className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-4 ${state.view === 'completed' ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}>
            <Archive className="w-5 h-5" />
            <span>Completed</span>
            <span className="ml-auto text-xs text-gray-500">{stats.completed}</span>
          </button>

          {/* Filters */}
          <div className="mb-2 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase">Filters</div>
          {state.filters.map(filter => (
            <button key={filter.id} onClick={() => setState(prev => ({ ...prev, view: 'filter', selectedFilterId: filter.id }))} className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-1 ${state.view === 'filter' && state.selectedFilterId === filter.id ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}>
              <FilterIcon className="w-4 h-4" style={{ color: filter.color }} />
              <span className="flex-1 text-left">{filter.name}</span>
            </button>
          ))}

          {/* Labels */}
          <div className="mt-4 mb-2 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase">Labels</div>
          {state.labels.map(label => (
            <button key={label.id} className="w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-1 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700">
              <Tag className="w-4 h-4" style={{ color: label.color }} />
              <span className="flex-1 text-left">{label.name}</span>
              <span className="text-xs text-gray-500">{state.tasks.filter(t => t.labels.includes(label.name)).length}</span>
            </button>
          ))}

          {/* Projects */}
          <div className="mt-4 mb-2 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase">Projects</div>
          {state.projects.filter(p => !p.isArchived).map(project => (
            <button key={project.id} onClick={() => setState(prev => ({ ...prev, view: 'project', selectedProjectId: project.id }))} className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg mb-1 ${state.view === 'project' && state.selectedProjectId === project.id ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-400' : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'}`}>
              <div className="w-3 h-3 rounded-full" style={{ backgroundColor: project.color }} />
              <span className="flex-1 text-left">{project.name}</span>
              <span className="text-xs text-gray-500">{state.tasks.filter(t => t.projectId === project.id && !t.completed).length}</span>
            </button>
          ))}
        </nav>

        <div className="p-3 border-t border-gray-200 dark:border-gray-700 space-y-2">
          <button onClick={() => handleExport('json')} className="w-full flex items-center justify-center gap-2 px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg">
            <Download className="w-4 h-4" />
            Export JSON
          </button>
          <button onClick={() => setState(prev => ({ ...prev, theme: prev.theme === 'light' ? 'dark' : 'light' }))} className="w-full flex items-center justify-center gap-2 px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg">
            {state.theme === 'light' ? <Moon className="w-4 h-4" /> : <Sun className="w-4 h-4" />}
            {state.theme === 'light' ? 'Dark' : 'Light'} Mode
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 p-4">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-2xl font-bold text-gray-800 dark:text-white">
              {state.view === 'filter' && state.selectedFilterId
                ? state.filters.find(f => f.id === state.selectedFilterId)?.name
                : currentProject?.name || state.view.charAt(0).toUpperCase() + state.view.slice(1)}
            </h2>
            <div className="flex items-center gap-4">
              <div className="relative">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <input type="text" placeholder="Search tasks..." value={state.searchQuery} onChange={(e) => setState(prev => ({ ...prev, searchQuery: e.target.value }))} className="pl-9 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-transparent" />
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                <span className="font-semibold">{stats.pending}</span> pending · <span className="font-semibold">{stats.completed}</span> completed
                {stats.overdue > 0 && <span className="ml-2 text-red-600">· <span className="font-semibold">{stats.overdue}</span> overdue</span>}
              </div>
              {state.selectedTasks.length > 0 && (
                <button onClick={() => setShowBulkActions(!showBulkActions)} className="flex items-center gap-2 px-3 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700">
                  <CheckSquare className="w-4 h-4" />
                  {state.selectedTasks.length} selected
                </button>
              )}
            </div>
          </div>

          {showBulkActions && (
            <div className="flex gap-2 p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
              <button onClick={bulkComplete} className="px-3 py-1 text-sm bg-green-600 text-white rounded hover:bg-green-700">Complete All</button>
              <button onClick={bulkDelete} className="px-3 py-1 text-sm bg-red-600 text-white rounded hover:bg-red-700">Delete All</button>
              <select onChange={(e) => bulkMove(e.target.value)} className="px-3 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800">
                <option value="">Move to...</option>
                {state.projects.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
              </select>
              <button onClick={() => { setState(prev => ({ ...prev, selectedTasks: [] })); setShowBulkActions(false); }} className="px-3 py-1 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200">Cancel</button>
            </div>
          )}
        </header>

        <div className="flex-1 overflow-y-auto p-6">
          <div className="max-w-4xl mx-auto space-y-2">
            {filteredTasks.map(task => (
              <div key={task.id} className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 hover:shadow-md transition-shadow">
                {editingTaskId === task.id ? (
                  /* Edit Mode */
                  <div className="space-y-3">
                    <input type="text" value={editingContent} onChange={(e) => setEditingContent(e.target.value)} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-800 dark:text-white" placeholder="Task name" />
                    <textarea value={editingDescription} onChange={(e) => setEditingDescription(e.target.value)} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-800 dark:text-white" rows={2} placeholder="Description" />
                    <div className="flex gap-2">
                      <input type="date" value={editingDate} onChange={(e) => setEditingDate(e.target.value)} className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-800 dark:text-white" />
                      <select value={editingPriority} onChange={(e) => setEditingPriority(e.target.value as Priority)} className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-800 dark:text-white">
                        <option value="p1">P1</option>
                        <option value="p2">P2</option>
                        <option value="p3">P3</option>
                        <option value="p4">P4</option>
                      </select>
                      <select value={editingProjectId} onChange={(e) => setEditingProjectId(e.target.value)} className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-800 dark:text-white">
                        {state.projects.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
                      </select>
                    </div>
                    <div className="flex gap-2">
                      <button onClick={saveTaskEdit} className="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700 flex items-center gap-1">
                        <Save className="w-4 h-4" /> Save
                      </button>
                      <button onClick={cancelEdit} className="px-3 py-1 bg-gray-300 dark:bg-gray-600 text-gray-800 dark:text-white rounded hover:bg-gray-400 dark:hover:bg-gray-500 flex items-center gap-1">
                        <X className="w-4 h-4" /> Cancel
                      </button>
                    </div>
                  </div>
                ) : (
                  /* View Mode */
                  <div>
                    <div className="flex items-start gap-3">
                      <input type="checkbox" checked={state.selectedTasks.includes(task.id)} onChange={() => toggleTaskSelection(task.id)} className="mt-1 w-4 h-4 rounded border-gray-300" />
                      <button onClick={() => toggleTask(task.id)} className="mt-1 w-5 h-5 rounded-full border-2 border-gray-300 dark:border-gray-600 hover:border-primary-600 dark:hover:border-primary-400 flex items-center justify-center flex-shrink-0">
                        {task.completed && <Check className="w-3 h-3 text-primary-600" />}
                      </button>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <p className={`text-gray-800 dark:text-white ${task.completed ? 'line-through text-gray-400' : ''}`} onDoubleClick={() => startEditingTask(task)}>{task.content}</p>
                          <span className={`text-xs px-2 py-0.5 border rounded ${priorityColors[task.priority]}`}>{task.priority.toUpperCase()}</span>
                          {task.subTasks && task.subTasks.length > 0 && (
                            <span className="text-xs text-gray-500">{task.subTasks.filter(st => st.completed).length}/{task.subTasks.length}</span>
                          )}
                        </div>
                        {task.description && <p className="text-sm text-gray-600 dark:text-gray-400 mb-2">{task.description}</p>}
                        <div className="flex items-center gap-3 text-xs text-gray-500 dark:text-gray-400">
                          {task.dueDate && (
                            <span className={`flex items-center gap-1 ${task.dueDate && isPast(parseISO(task.dueDate)) && !task.completed ? 'text-red-600' : ''}`}>
                              <Calendar className="w-3 h-3" />
                              {format(parseISO(task.dueDate), 'MMM d, yyyy')}
                            </span>
                          )}
                          {task.labels.map(label => {
                            const labelObj = state.labels.find(l => l.name === label);
                            return <span key={label} className="px-2 py-0.5 rounded text-white" style={{ backgroundColor: labelObj?.color || '#6366f1' }}>{label}</span>;
                          })}
                          {task.comments && task.comments.length > 0 && (
                            <span className="flex items-center gap-1"><MessageSquare className="w-3 h-3" /> {task.comments.length}</span>
                          )}
                          {task.attachments && task.attachments.length > 0 && (
                            <span className="flex items-center gap-1"><Paperclip className="w-3 h-3" /> {task.attachments.length}</span>
                          )}
                          {task.recurring && <Repeat className="w-3 h-3" />}
                        </div>

                        {/* Subtasks */}
                        {task.subTasks && task.subTasks.length > 0 && (
                          <div className="mt-2 ml-8 space-y-1">
                            {task.subTasks.map(subTask => (
                              <div key={subTask.id} className="flex items-center gap-2">
                                <button onClick={() => toggleSubTask(task.id, subTask.id)} className="w-4 h-4 rounded border border-gray-300 flex items-center justify-center">
                                  {subTask.completed && <Check className="w-3 h-3 text-primary-600" />}
                                </button>
                                <span className={`text-sm ${subTask.completed ? 'line-through text-gray-400' : 'text-gray-700 dark:text-gray-300'}`}>{subTask.content}</span>
                              </div>
                            ))}
                          </div>
                        )}

                        {/* Task Details Panel */}
                        {showTaskDetails === task.id && (
                          <div className="mt-3 p-3 bg-gray-50 dark:bg-gray-700 rounded space-y-3">
                            {/* Add Subtask */}
                            <div>
                              <label className="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">Add Subtask</label>
                              <div className="flex gap-2">
                                <input type="text" value={newSubTaskContent} onChange={(e) => setNewSubTaskContent(e.target.value)} className="flex-1 px-3 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800" placeholder="Subtask name" />
                                <button onClick={() => addSubTask(task.id)} className="px-3 py-1 bg-primary-600 text-white rounded hover:bg-primary-700 text-sm">Add</button>
                              </div>
                            </div>

                            {/* Comments */}
                            <div>
                              <label className="block text-xs font-semibold text-gray-600 dark:text-gray-400 mb-1">Comments</label>
                              {task.comments && task.comments.length > 0 && (
                                <div className="space-y-2 mb-2">
                                  {task.comments.map(comment => (
                                    <div key={comment.id} className="p-2 bg-white dark:bg-gray-800 rounded">
                                      <p className="text-sm text-gray-800 dark:text-white">{comment.content}</p>
                                      <p className="text-xs text-gray-500 mt-1">{format(parseISO(comment.createdAt), 'MMM d, h:mm a')}</p>
                                    </div>
                                  ))}
                                </div>
                              )}
                              <div className="flex gap-2">
                                <input type="text" value={newCommentContent} onChange={(e) => setNewCommentContent(e.target.value)} className="flex-1 px-3 py-1 text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800" placeholder="Add a comment" />
                                <button onClick={() => addComment(task.id)} className="px-3 py-1 bg-primary-600 text-white rounded hover:bg-primary-700 text-sm">Comment</button>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                      <div className="flex gap-1">
                        <button onClick={() => startEditingTask(task)} className="text-gray-400 hover:text-blue-600 dark:hover:text-blue-400">
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button onClick={() => setShowTaskDetails(showTaskDetails === task.id ? null : task.id)} className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
                          <MoreVertical className="w-4 h-4" />
                        </button>
                        <button onClick={() => deleteTask(task.id)} className="text-gray-400 hover:text-red-600 dark:hover:text-red-400">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            ))}

            {filteredTasks.length === 0 && (
              <div className="text-center py-12 text-gray-500 dark:text-gray-400">
                <CheckCircle className="w-16 h-16 mx-auto mb-4 opacity-20" />
                <p>No tasks found. Add a new task to get started!</p>
              </div>
            )}
          </div>
        </div>

        {/* Add Task Bar */}
        <div className="bg-white dark:bg-gray-800 border-t border-gray-200 dark:border-gray-700 p-4">
          <div className="max-w-4xl mx-auto">
            <div className="flex gap-3 mb-2">
              <input type="text" placeholder="Add a new task..." value={newTaskContent} onChange={(e) => setNewTaskContent(e.target.value)} onKeyPress={(e) => e.key === 'Enter' && addTask()} className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white focus:ring-2 focus:ring-primary-500 focus:border-transparent" />
              <input type="date" value={newTaskDate} onChange={(e) => setNewTaskDate(e.target.value)} className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white" />
              <select value={newTaskPriority} onChange={(e) => setNewTaskPriority(e.target.value as Priority)} className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-800 dark:text-white">
                <option value="p1">P1</option>
                <option value="p2">P2</option>
                <option value="p3">P3</option>
                <option value="p4">P4</option>
              </select>
              <button onClick={addTask} className="px-6 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg font-medium flex items-center gap-2">
                <Plus className="w-4 h-4" />
                Add Task
              </button>
            </div>

            {/* Label Selection */}
            <div className="flex gap-2 flex-wrap">
              {state.labels.map(label => (
                <button key={label.id} onClick={() => setSelectedLabels(prev => prev.includes(label.name) ? prev.filter(l => l !== label.name) : [...prev, label.name])} className={`px-2 py-1 text-xs rounded ${selectedLabels.includes(label.name) ? 'text-white' : 'text-gray-600 dark:text-gray-400 border border-gray-300 dark:border-gray-600'}`} style={selectedLabels.includes(label.name) ? { backgroundColor: label.color } : {}}>
                  {label.name}
                </button>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
