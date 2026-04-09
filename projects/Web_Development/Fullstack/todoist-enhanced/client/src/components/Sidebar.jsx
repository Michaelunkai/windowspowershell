import { useState, useEffect, useCallback } from 'react'
import { useTheme } from '../context/ThemeContext'
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  DragOverlay,
} from '@dnd-kit/core'
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import CreateProjectDialog from './CreateProjectDialog'
import ProjectProgress from './ProjectProgress'
import EmptyState from './EmptyState'

const API_BASE = 'http://localhost:3456'

// ─── Nav icons ───────────────────────────────────────────────────────────────

function HomeIcon() {
  return (
    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
    </svg>
  )
}

function InboxNavIcon() {
  return (
    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
    </svg>
  )
}

function TodayIcon() {
  return (
    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" strokeLinecap="round" />
      <line x1="8" y1="2" x2="8" y2="6" strokeLinecap="round" />
      <line x1="3" y1="10" x2="21" y2="10" strokeLinecap="round" />
    </svg>
  )
}

function UpcomingIcon() {
  return (
    <svg className="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
    </svg>
  )
}

function ChevronIcon({ open }) {
  return (
    <svg
      className={`w-3 h-3 shrink-0 transition-transform duration-200 ${open ? 'rotate-90' : ''}`}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      strokeWidth={2.5}
    >
      <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
    </svg>
  )
}

// ─── NavItem ─────────────────────────────────────────────────────────────────

function NavItem({ icon, label, count, isActive, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full flex items-center gap-2.5 px-3 py-1.5 rounded text-sm text-left transition-colors ${isActive ? 'font-medium' : ''}`}
      style={isActive ? { backgroundColor: '#DB4035', color: '#ffffff' } : { color: '#d1d5db' }}
      onMouseEnter={(e) => { if (!isActive) e.currentTarget.style.backgroundColor = '#3D3D3D' }}
      onMouseLeave={(e) => { if (!isActive) e.currentTarget.style.backgroundColor = '' }}
    >
      {icon}
      <span className="flex-1 truncate">{label}</span>
      {count > 0 && (
        <span className="text-xs shrink-0" style={{ color: isActive ? 'rgba(255,255,255,0.75)' : '#9ca3af' }}>
          {count}
        </span>
      )}
    </button>
  )
}

// ─── SectionHeader (collapsible) ─────────────────────────────────────────────

function SectionHeader({ label, open, onToggle, onAdd }) {
  return (
    <div className="flex items-center justify-between px-2 py-1 group mt-1">
      <button
        type="button"
        onClick={onToggle}
        className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider transition-colors select-none"
        style={{ color: '#9ca3af' }}
        onMouseEnter={(e) => { e.currentTarget.style.color = '#d1d5db' }}
        onMouseLeave={(e) => { e.currentTarget.style.color = '#9ca3af' }}
      >
        <ChevronIcon open={open} />
        <span>{label}</span>
      </button>
      {onAdd && (
        <button
          type="button"
          onClick={onAdd}
          className="opacity-0 group-hover:opacity-100 transition-opacity rounded p-0.5"
          style={{ color: '#9ca3af' }}
          onMouseEnter={(e) => { e.currentTarget.style.color = '#ffffff'; e.currentTarget.style.backgroundColor = '#3D3D3D' }}
          onMouseLeave={(e) => { e.currentTarget.style.color = '#9ca3af'; e.currentTarget.style.backgroundColor = '' }}
          aria-label={`Add ${label.toLowerCase()}`}
          title={`Add ${label.toLowerCase()}`}
        >
          <svg className="w-4 h-4" viewBox="0 0 20 20" fill="currentColor">
            <path fillRule="evenodd" d="M10 5a1 1 0 011 1v3h3a1 1 0 110 2h-3v3a1 1 0 11-2 0v-3H6a1 1 0 110-2h3V6a1 1 0 011-1z" clipRule="evenodd" />
          </svg>
        </button>
      )}
    </div>
  )
}

// Drag handle icon
function GripIcon() {
  return (
    <svg
      className="w-3.5 h-3.5 text-gray-400 shrink-0"
      viewBox="0 0 20 20"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M7 4a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm6-14a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
    </svg>
  )
}

// Star icon for favorites toggle
function StarIcon({ filled, className = '' }) {
  return (
    <svg
      className={`w-3.5 h-3.5 shrink-0 ${className}`}
      viewBox="0 0 20 20"
      fill={filled ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth={filled ? 0 : 1.5}
      aria-hidden="true"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"
      />
    </svg>
  )
}

// Filter icon shown in Favorites section next to filter items
function FilterIcon() {
  return (
    <svg
      className="w-3.5 h-3.5 shrink-0 text-purple-500"
      viewBox="0 0 20 20"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        fillRule="evenodd"
        d="M3 3a1 1 0 011-1h12a1 1 0 011 1v3a1 1 0 01-.293.707L13 10.414V15a1 1 0 01-.553.894l-4 2A1 1 0 017 17v-6.586L3.293 6.707A1 1 0 013 6V3z"
        clipRule="evenodd"
      />
    </svg>
  )
}

function SortableProject({ project, isActive, onSelect, onToggleFavorite }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: project.id })

  // Todoist color scheme: active = red #DB4035 with white text, hover = #3D3D3D on dark sidebar
  const baseStyle = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
    ...(isActive ? { backgroundColor: '#DB4035', color: '#ffffff' } : { color: '#d1d5db' }),
  }

  return (
    <div
      ref={setNodeRef}
      style={baseStyle}
      className={`flex flex-col px-3 py-1.5 rounded cursor-pointer select-none group transition-colors ${
        isActive ? 'font-medium' : ''
      }`}
      onMouseEnter={(e) => { if (!isActive) e.currentTarget.style.backgroundColor = '#3D3D3D' }}
      onMouseLeave={(e) => { if (!isActive) e.currentTarget.style.backgroundColor = '' }}
      onClick={() => onSelect(project)}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => e.key === 'Enter' && onSelect(project)}
      aria-label={`Project: ${project.name}`}
    >
      {/* Top row: drag handle + color dot + name + task count */}
      <div className="flex items-center gap-2">
        {/* Drag handle */}
        <span
          {...attributes}
          {...listeners}
          className="opacity-0 group-hover:opacity-100 cursor-grab active:cursor-grabbing touch-none"
          aria-label="Drag to reorder"
          onClick={(e) => e.stopPropagation()}
        >
          <GripIcon />
        </span>

        {/* Color dot */}
        <span
          className="w-2.5 h-2.5 rounded-full shrink-0"
          style={{ backgroundColor: project.color || '#6366f1' }}
        />

        {/* Name */}
        <span className="flex-1 truncate text-sm">{project.name}</span>

        {/* Task count (incomplete tasks) */}
        {project.task_count > 0 && (
          <span className="text-xs shrink-0" style={{ color: isActive ? 'rgba(255,255,255,0.8)' : '#9ca3af' }}>
            {project.task_count}
          </span>
        )}

        {/* Star toggle — visible when favorited or on hover */}
        <button
          className={`transition-opacity ml-0.5 ${
            project.is_favorite
              ? 'opacity-100 text-yellow-400'
              : 'opacity-0 group-hover:opacity-100 text-gray-500 hover:text-yellow-400'
          }`}
          onClick={(e) => {
            e.stopPropagation()
            onToggleFavorite('project', project)
          }}
          title={project.is_favorite ? 'Remove from favorites' : 'Add to favorites'}
          aria-label={project.is_favorite ? 'Remove from favorites' : 'Add to favorites'}
        >
          <StarIcon filled={!!project.is_favorite} />
        </button>
      </div>

      {/* Progress bar: X/Y completed with percentage */}
      <ProjectProgress
        completedCount={project.completed_count || 0}
        totalCount={project.total_count || 0}
      />
    </div>
  )
}

export default function Sidebar({ activeProjectId, onSelectProject, token, activeView, onSelectView }) {
  const [projects, setProjects] = useState([])
  const [filters, setFilters] = useState([])
  const [labels, setLabels] = useState([])
  const [tasks, setTasks] = useState([])
  const [activeId, setActiveId] = useState(null)
  // Expand/collapse state for collapsible sections
  const [projectsOpen, setProjectsOpen] = useState(true)
  const [labelsOpen, setLabelsOpen] = useState(true)
  const [filtersOpen, setFiltersOpen] = useState(true)
  const { isDark, toggleTheme } = useTheme()
  const [showCreateDialog, setShowCreateDialog] = useState(false)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  )

  const fetchProjects = useCallback(async () => {
    if (!token) return
    try {
      const res = await fetch(`${API_BASE}/api/projects`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.ok) {
        const data = await res.json()
        setProjects(data.projects || [])
      }
    } catch (err) {
      console.error('Failed to fetch projects:', err)
    }
  }, [token])

  const fetchFilters = async () => {
    if (!token) return
    try {
      const res = await fetch(API_BASE + '/api/filters', {
        headers: { Authorization: 'Bearer ' + token },
      })
      if (res.ok) {
        const data = await res.json()
        setFilters(Array.isArray(data) ? data : (data.filters || []))
      }
    } catch (err) {
      console.error('Failed to fetch filters:', err)
    }
  }

  const fetchLabels = useCallback(async () => {
    if (!token) return
    try {
      const res = await fetch(`${API_BASE}/api/labels`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.ok) {
        const data = await res.json()
        setLabels(data.labels || [])
      }
    } catch (err) {
      console.error('Sidebar: failed to fetch labels:', err)
    }
  }, [token])

  const fetchTasks = useCallback(async () => {
    if (!token) return
    try {
      const res = await fetch(`${API_BASE}/api/tasks?completed=false&limit=500`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.ok) {
        const data = await res.json()
        setTasks(data.tasks || data || [])
      }
    } catch (err) {
      console.error('Sidebar: failed to fetch tasks:', err)
    }
  }, [token])

  useEffect(() => {
    fetchProjects()
    fetchFilters()
    fetchLabels()
    fetchTasks()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [fetchProjects, fetchLabels, fetchTasks, token])

  const handleDragStart = ({ active }) => setActiveId(active.id)

  const handleDragEnd = async ({ active, over }) => {
    setActiveId(null)
    if (!over || active.id === over.id) return

    const oldIndex = projects.findIndex((p) => p.id === active.id)
    const newIndex = projects.findIndex((p) => p.id === over.id)
    if (oldIndex === -1 || newIndex === -1) return

    const reordered = arrayMove(projects, oldIndex, newIndex)
    setProjects(reordered) // optimistic update

    const payload = reordered.map((p, i) => ({ id: p.id, sort_order: i }))
    try {
      await fetch(`${API_BASE}/api/projects/reorder`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ projects: payload }),
      })
    } catch (err) {
      console.error('Failed to save project order:', err)
      fetchProjects() // revert on error
    }
  }

  const handleProjectCreated = (newProject) => {
    setProjects((prev) => [...prev, newProject])
  }

  const handleToggleFavorite = async (type, item) => {
    const newFav = !item.is_favorite
    if (type === 'project') {
      setProjects((prev) =>
        prev.map((p) => (p.id === item.id ? { ...p, is_favorite: newFav } : p))
      )
      try {
        await fetch(API_BASE + '/api/projects/' + item.id, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify({
            name: item.name, color: item.color, icon: item.icon,
            isFavorite: newFav, viewType: item.view_type,
          }),
        })
      } catch (err) {
        console.error('Failed to toggle project favorite:', err)
        fetchProjects()
      }
    } else if (type === 'filter') {
      setFilters((prev) =>
        prev.map((f) => (f.id === item.id ? { ...f, is_favorite: newFav } : f))
      )
      try {
        await fetch(API_BASE + '/api/filters/' + item.id, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
          body: JSON.stringify({
            name: item.name, query: item.query, color: item.color, is_favorite: newFav,
          }),
        })
      } catch (err) {
        console.error('Failed to toggle filter favorite:', err)
        fetchFilters()
      }
    }
  }

  const activeProject = activeId ? projects.find((p) => p.id === activeId) : null
  // Separate inbox from regular projects for DnD (inbox is pinned at top)
  const inboxProjects = projects.filter((p) => p.is_inbox)
  const inboxProject = inboxProjects[0] || null
  const regularProjects = projects.filter((p) => !p.is_inbox)

  // Favorites: starred non-inbox projects + starred filters — shown above Inbox
  const favoriteProjects = projects.filter((p) => !p.is_inbox && p.is_favorite)
  const favoriteFilters = filters.filter((f) => f.is_favorite)
  const hasFavorites = favoriteProjects.length > 0 || favoriteFilters.length > 0

  // Today / Upcoming counts derived from fetched tasks
  const todayStr = new Date().toISOString().slice(0, 10)
  const nextWeekStr = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
  const todayCount = tasks.filter((t) => !t.completed && t.due_date === todayStr).length
  const upcomingCount = tasks.filter(
    (t) => !t.completed && t.due_date && t.due_date > todayStr && t.due_date <= nextWeekStr
  ).length
  const inboxCount = inboxProject ? (inboxProject.task_count || 0) : 0

  // Active view helpers — support new activeView prop OR legacy activeProjectId
  const isViewActive = (type, id) => {
    if (activeView) {
      if (id != null) return activeView.type === type && String(activeView.id) === String(id)
      return activeView.type === type
    }
    if ((type === 'project' || type === 'inbox') && id != null) return String(activeProjectId) === String(id)
    return false
  }

  const handleSelectProject = (project) => {
    if (onSelectView) {
      onSelectView({ type: project.is_inbox ? 'inbox' : 'project', id: project.id, project })
    } else if (onSelectProject) {
      onSelectProject(project)
    }
  }

  const handleSelectView = (type, extra) => {
    if (onSelectView) onSelectView({ type, ...extra })
  }

  return (
    <>
    <div className="flex flex-col h-full overflow-y-auto py-3 px-2 space-y-0.5" style={{ backgroundColor: '#1f2937', color: '#e5e7eb' }}>

      {/* ── Main nav: Home / Inbox / Today / Upcoming ─────────────────────── */}
      <NavItem
        icon={<HomeIcon />}
        label="Home"
        count={0}
        isActive={isViewActive('home')}
        onClick={() => handleSelectView('home')}
      />
      <NavItem
        icon={<InboxNavIcon />}
        label="Inbox"
        count={inboxCount}
        isActive={isViewActive('inbox', inboxProject ? inboxProject.id : null)}
        onClick={() => inboxProject && handleSelectProject(inboxProject)}
      />
      <NavItem
        icon={<TodayIcon />}
        label="Today"
        count={todayCount}
        isActive={isViewActive('today')}
        onClick={() => handleSelectView('today')}
      />
      <NavItem
        icon={<UpcomingIcon />}
        label="Upcoming"
        count={upcomingCount}
        isActive={isViewActive('upcoming')}
        onClick={() => handleSelectView('upcoming')}
      />

      <div className="my-2 border-t" style={{ borderColor: '#374151' }} />

      {/* ── Filters section ─────────────────────────────────────────────────── */}
      {filters.length > 0 && (
        <>
          <SectionHeader
            label="Filters"
            open={filtersOpen}
            onToggle={() => setFiltersOpen((v) => !v)}
          />
          {filtersOpen && filters.map((filter) => (
            <button
              key={filter.id}
              type="button"
              onClick={() => handleSelectView('filter', { id: filter.id, filter })}
              className={`w-full flex items-center gap-2.5 px-3 py-1.5 rounded text-sm text-left transition-colors ${isViewActive('filter', filter.id) ? 'font-medium' : ''}`}
              style={isViewActive('filter', filter.id) ? { backgroundColor: '#DB4035', color: '#ffffff' } : { color: '#d1d5db' }}
              onMouseEnter={(e) => { if (!isViewActive('filter', filter.id)) e.currentTarget.style.backgroundColor = '#3D3D3D' }}
              onMouseLeave={(e) => { if (!isViewActive('filter', filter.id)) e.currentTarget.style.backgroundColor = '' }}
            >
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: filter.color || '#6366f1' }} />
              <span className="flex-1 truncate">{filter.name}</span>
            </button>
          ))}
          <div className="my-2 border-t" style={{ borderColor: '#374151' }} />
        </>
      )}

      {/* ── Labels section ──────────────────────────────────────────────────── */}
      {labels.length > 0 && (
        <>
          <SectionHeader
            label="Labels"
            open={labelsOpen}
            onToggle={() => setLabelsOpen((v) => !v)}
          />
          {labelsOpen && labels.map((label) => (
            <button
              key={label.id}
              type="button"
              onClick={() => handleSelectView('label', { id: label.id, label })}
              className={`w-full flex items-center gap-2.5 px-3 py-1.5 rounded text-sm text-left transition-colors ${isViewActive('label', label.id) ? 'font-medium' : ''}`}
              style={isViewActive('label', label.id) ? { backgroundColor: '#DB4035', color: '#ffffff' } : { color: '#d1d5db' }}
              onMouseEnter={(e) => { if (!isViewActive('label', label.id)) e.currentTarget.style.backgroundColor = '#3D3D3D' }}
              onMouseLeave={(e) => { if (!isViewActive('label', label.id)) e.currentTarget.style.backgroundColor = '' }}
            >
              <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: label.color || '#6366f1' }} />
              <span className="flex-1 truncate">{label.name}</span>
              {label.task_count > 0 && (
                <span className="text-xs shrink-0" style={{ color: isViewActive('label', label.id) ? 'rgba(255,255,255,0.8)' : '#9ca3af' }}>
                  {label.task_count}
                </span>
              )}
            </button>
          ))}
          <div className="my-2 border-t" style={{ borderColor: '#374151' }} />
        </>
      )}

      {/* Favorites section — shown when any item is starred */}
      {hasFavorites && (
        <>
          <p className="px-3 text-xs font-semibold uppercase tracking-wider mb-1" style={{ color: '#9ca3af' }}>
            Favorites
          </p>

          {favoriteProjects.map((project) => {
            const isFavActive = activeProjectId === project.id
            return (
              <div
                key={'fav-proj-' + project.id}
                className={'flex items-center gap-2 px-3 py-1.5 rounded cursor-pointer select-none group transition-colors' + (isFavActive ? ' font-medium' : '')}
                style={isFavActive ? { backgroundColor: '#DB4035', color: '#ffffff' } : { color: '#d1d5db' }}
                onMouseEnter={(e) => { if (!isFavActive) e.currentTarget.style.backgroundColor = '#3D3D3D' }}
                onMouseLeave={(e) => { if (!isFavActive) e.currentTarget.style.backgroundColor = '' }}
                onClick={() => onSelectProject(project)}
                role="button"
                tabIndex={0}
                onKeyDown={(e) => e.key === 'Enter' && onSelectProject(project)}
                aria-label={'Favorite project: ' + project.name}
              >
                <span className="w-3.5 h-3.5 shrink-0" />
                <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: project.color || '#6366f1' }} />
                <span className="flex-1 truncate text-sm">{project.name}</span>
                {project.task_count > 0 && (
                  <span className="text-xs shrink-0" style={{ color: isFavActive ? 'rgba(255,255,255,0.8)' : '#9ca3af' }}>
                    {project.task_count}
                  </span>
                )}
                <button
                  className="opacity-100 text-yellow-400 ml-0.5"
                  onClick={(e) => { e.stopPropagation(); handleToggleFavorite('project', project) }}
                  title="Remove from favorites"
                  aria-label="Remove from favorites"
                >
                  <StarIcon filled={true} />
                </button>
              </div>
            )
          })}

          {favoriteFilters.map((filter) => (
            <div
              key={'fav-filter-' + filter.id}
              className="flex items-center gap-2 px-3 py-1.5 rounded cursor-pointer select-none group transition-colors"
              style={{ color: '#d1d5db' }}
              onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = '#3D3D3D' }}
              onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = '' }}
              role="button"
              tabIndex={0}
              aria-label={'Favorite filter: ' + filter.name}
            >
              <span className="w-3.5 h-3.5 shrink-0" />
              <FilterIcon />
              <span className="flex-1 truncate text-sm">{filter.name}</span>
              <button
                className="opacity-100 text-yellow-400 ml-0.5"
                onClick={(e) => { e.stopPropagation(); handleToggleFavorite('filter', filter) }}
                title="Remove from favorites"
                aria-label="Remove from favorites"
              >
                <StarIcon filled={true} />
              </button>
            </div>
          ))}

          <hr className="border-gray-700 mx-3 my-1" />
        </>
      )}

      {/* Projects section header — collapsible with Add button + theme toggle */}
      <SectionHeader
        label="Projects"
        open={projectsOpen}
        onToggle={() => setProjectsOpen((v) => !v)}
        onAdd={() => setShowCreateDialog(true)}
      />

      {/* Theme toggle (inside projects section) */}
      {projectsOpen && (
        <div className="px-3 py-0.5 mb-0.5">
          <button
            type="button"
            onClick={toggleTheme}
            className="flex items-center gap-1.5 text-xs rounded px-1.5 py-0.5 transition-colors"
            style={{ color: '#9ca3af' }}
            onMouseEnter={(e) => { e.currentTarget.style.color = '#ffffff'; e.currentTarget.style.backgroundColor = '#3D3D3D' }}
            onMouseLeave={(e) => { e.currentTarget.style.color = '#9ca3af'; e.currentTarget.style.backgroundColor = '' }}
            aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
            title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            {isDark ? (
              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364-6.364l-.707.707M6.343 17.657l-.707.707M17.657 17.657l-.707-.707M6.343 6.343l-.707-.707M12 8a4 4 0 100 8 4 4 0 000-8z" />
              </svg>
            ) : (
              <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 12.79A9 9 0 1111.21 3a7 7 0 009.79 9.79z" />
              </svg>
            )}
            <span>{isDark ? 'Light mode' : 'Dark mode'}</span>
          </button>
        </div>
      )}

      {/* Inbox (not draggable) — only shown when projects section is open */}
      {projectsOpen && inboxProjects.map((project) => {
        const isInboxActive = isViewActive('inbox', project.id)
        return (
          <div
            key={project.id}
            className="flex flex-col px-3 py-1.5 rounded cursor-pointer select-none transition-colors"
            style={isInboxActive
              ? { backgroundColor: '#DB4035', color: '#ffffff', fontWeight: 500 }
              : { color: '#d1d5db' }
            }
            onMouseEnter={(e) => { if (!isInboxActive) e.currentTarget.style.backgroundColor = '#3D3D3D' }}
            onMouseLeave={(e) => { if (!isInboxActive) e.currentTarget.style.backgroundColor = '' }}
            onClick={() => handleSelectProject(project)}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => e.key === 'Enter' && handleSelectProject(project)}
          >
            {/* Top row */}
            <div className="flex items-center gap-2">
              <span className="w-3.5 h-3.5 shrink-0" /> {/* placeholder for grip */}
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: project.color || '#6366f1' }}
              />
              <span className="flex-1 truncate text-sm">{project.name}</span>
              {project.task_count > 0 && (
                <span className="text-xs shrink-0" style={{ color: isInboxActive ? 'rgba(255,255,255,0.8)' : '#9ca3af' }}>
                  {project.task_count}
                </span>
              )}
            </div>

            {/* Progress bar: X/Y completed with percentage */}
            <ProjectProgress
              completedCount={project.completed_count || 0}
              totalCount={project.total_count || 0}
            />
          </div>
        )
      })}

      {/* Projects empty state — shown when no user-created projects exist */}
      {projectsOpen && regularProjects.length === 0 && (
        <div className="px-2 py-2">
          <EmptyState type="projects" />
        </div>
      )}

      {/* Draggable regular projects — only shown when projects section is open */}
      {projectsOpen && (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <SortableContext
            items={regularProjects.map((p) => p.id)}
            strategy={verticalListSortingStrategy}
          >
            {regularProjects.map((project) => (
              <SortableProject
                key={project.id}
                project={project}
                isActive={isViewActive('project', project.id)}
                onSelect={handleSelectProject}
                onToggleFavorite={handleToggleFavorite}
              />
            ))}
          </SortableContext>

          <DragOverlay>
            {activeProject && (
              <div
                className="flex items-center gap-2 px-3 py-1.5 rounded shadow-lg opacity-90 text-sm border"
                style={{ backgroundColor: '#3D3D3D', color: '#ffffff', borderColor: '#4D4D4D' }}
              >
                <GripIcon />
                <span
                  className="w-2.5 h-2.5 rounded-full shrink-0"
                  style={{ backgroundColor: activeProject.color || '#6366f1' }}
                />
                <span className="truncate">{activeProject.name}</span>
              </div>
            )}
          </DragOverlay>
        </DndContext>
      )}
    </div>

    {showCreateDialog && (
      <CreateProjectDialog
        token={token}
        onProjectCreated={handleProjectCreated}
        onClose={() => setShowCreateDialog(false)}
      />
    )}
    </>
  )
}



