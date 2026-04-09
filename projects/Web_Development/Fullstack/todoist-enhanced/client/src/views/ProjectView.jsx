/**
 * ProjectView — displays a single project with its sections and tasks.
 *
 * Features:
 *  - Fetches project details, sections, and tasks filtered by project_id
 *  - Renders sections as collapsible groups
 *  - Unsectioned tasks appear under a "No Section" group at the top
 *  - Tasks within each section are drag-sortable via @dnd-kit
 *  - Tasks can be dragged between sections (cross-section reorder)
 *  - Inline "Add task" quick-entry per section
 *  - Inline "Add section" at the bottom
 *
 * Props:
 *  projectId  {string}   — the project UUID to display
 *  token      {string}   — JWT for API calls
 *  onBack     {function} — called when the back button is clicked
 */

import { useState, useEffect, useCallback, useRef } from 'react'
import {
  DndContext,
  DragOverlay,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

const API = 'http://localhost:3456'

// ─── Priority helpers ────────────────────────────────────────────────────────
const PRIORITY_RING = {
  1: 'border-red-500',
  2: 'border-orange-500',
  3: 'border-blue-500',
  4: 'border-gray-300 dark:border-gray-600',
}
const PRIORITY_BADGE = {
  1: 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400',
  2: 'bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400',
  3: 'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400',
}

// ─── Drag handle icon ────────────────────────────────────────────────────────
function GripIcon({ className = '' }) {
  return (
    <svg
      className={`w-3.5 h-3.5 text-gray-400 ${className}`}
      viewBox="0 0 20 20"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M7 4a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm6-14a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" />
    </svg>
  )
}

// ─── SortableTaskRow ─────────────────────────────────────────────────────────
function SortableTaskRow({ task, token, onRefresh }) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: task.id, data: { task } })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  }

  const handleToggleComplete = async () => {
    try {
      await fetch(`${API}/api/tasks/${task.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ completed: !task.completed }),
      })
      onRefresh()
    } catch (err) {
      console.error('Toggle complete failed:', err)
    }
  }

  const priorityRing = PRIORITY_RING[task.priority] || PRIORITY_RING[4]
  const priorityBadgeClass = PRIORITY_BADGE[task.priority]

  return (
    <div
      ref={setNodeRef}
      style={style}
      className={[
        'group flex items-start gap-2 px-3 py-2 rounded-lg select-none',
        'hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors',
        task.completed ? 'opacity-50' : '',
      ].join(' ')}
      role="listitem"
      aria-label={task.title}
    >
      {/* Drag handle */}
      <span
        {...attributes}
        {...listeners}
        className="mt-0.5 opacity-0 group-hover:opacity-100 cursor-grab active:cursor-grabbing touch-none shrink-0"
        aria-label="Drag to reorder"
      >
        <GripIcon />
      </span>

      {/* Completion checkbox */}
      <button
        type="button"
        aria-label={task.completed ? 'Mark incomplete' : 'Mark complete'}
        onClick={handleToggleComplete}
        className={[
          'mt-0.5 shrink-0 w-5 h-5 rounded-full border-2 flex items-center justify-center',
          'transition-colors focus:outline-none focus:ring-2 focus:ring-offset-1',
          task.completed ? 'bg-green-500 border-green-500' : priorityRing,
        ].join(' ')}
      >
        {task.completed && (
          <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
          </svg>
        )}
      </button>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <p className={[
          'text-sm text-gray-900 dark:text-white leading-snug',
          task.completed ? 'line-through text-gray-400 dark:text-gray-500' : '',
        ].join(' ')}>
          {task.title}
        </p>
        {task.description && (
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 truncate">
            {task.description}
          </p>
        )}
        <div className="flex items-center gap-2 mt-0.5 flex-wrap">
          {task.due_date && (
            <span className="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-1">
              <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              {task.due_date}
            </span>
          )}
          {task.priority && task.priority !== 4 && (
            <span className={`text-xs font-semibold px-1.5 py-0.5 rounded ${priorityBadgeClass}`}>
              P{task.priority}
            </span>
          )}
        </div>
      </div>
    </div>
  )
}

// ─── DragOverlay ghost card ──────────────────────────────────────────────────
function TaskGhost({ task }) {
  return (
    <div className="flex items-center gap-2 px-3 py-2 rounded-lg bg-white dark:bg-gray-800 shadow-lg border border-gray-200 dark:border-gray-600 opacity-90">
      <GripIcon />
      <span className="w-5 h-5 rounded-full border-2 border-gray-300 dark:border-gray-600 shrink-0" />
      <span className="text-sm text-gray-900 dark:text-white truncate">{task?.title}</span>
    </div>
  )
}

// ─── Inline quick-add task form ──────────────────────────────────────────────
function QuickAddTask({ projectId, sectionId, token, onAdded }) {
  const [open, setOpen] = useState(false)
  const [title, setTitle] = useState('')
  const inputRef = useRef(null)

  const openForm = () => {
    setOpen(true)
    setTimeout(() => inputRef.current?.focus(), 0)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    const trimmed = title.trim()
    if (!trimmed) return
    try {
      const res = await fetch(`${API}/api/tasks`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          title: trimmed,
          project_id: projectId,
          section_id: sectionId || null,
        }),
      })
      if (res.ok) {
        setTitle('')
        setOpen(false)
        onAdded()
      }
    } catch (err) {
      console.error('Add task failed:', err)
    }
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Escape') {
      setOpen(false)
      setTitle('')
    }
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={openForm}
        className="flex items-center gap-1.5 text-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 px-3 py-1.5 rounded transition-colors"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        Add task
      </button>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="px-3 py-2">
      <input
        ref={inputRef}
        type="text"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Task name"
        className="w-full text-sm border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-1.5 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
      />
      <div className="flex gap-2 mt-2">
        <button
          type="submit"
          className="text-sm px-3 py-1 rounded bg-indigo-600 text-white hover:bg-indigo-700 transition-colors"
        >
          Add
        </button>
        <button
          type="button"
          onClick={() => { setOpen(false); setTitle('') }}
          className="text-sm px-3 py-1 rounded text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          Cancel
        </button>
      </div>
    </form>
  )
}

// ─── SectionGroup ────────────────────────────────────────────────────────────
/**
 * Renders one section header + its tasks list (sortable within this section).
 * The DndContext wrapping cross-section is at ProjectView level; here we only
 * provide the SortableContext for tasks within this section.
 */
function SectionGroup({
  section,
  tasks,
  token,
  projectId,
  onRefresh,
  onToggleCollapse,
  isCollapsed,
}) {
  const isEmpty = tasks.length === 0

  return (
    <div className="mb-4">
      {/* Section header */}
      <div className="flex items-center gap-2 px-2 py-1.5 group">
        <button
          type="button"
          onClick={() => onToggleCollapse(section.id)}
          className="flex items-center gap-1.5 flex-1 min-w-0 text-left focus:outline-none"
          aria-expanded={!isCollapsed}
          aria-label={`${isCollapsed ? 'Expand' : 'Collapse'} section ${section.name}`}
        >
          {/* Chevron */}
          <svg
            className={`w-4 h-4 text-gray-500 shrink-0 transition-transform duration-150 ${isCollapsed ? '-rotate-90' : ''}`}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
          <span className="text-sm font-semibold text-gray-700 dark:text-gray-200 truncate">
            {section.name}
          </span>
          <span className="text-xs text-gray-400 shrink-0 ml-1">
            {tasks.length}
          </span>
        </button>
      </div>

      {/* Tasks list */}
      {!isCollapsed && (
        <div>
          <SortableContext
            items={tasks.map((t) => t.id)}
            strategy={verticalListSortingStrategy}
          >
            <div role="list" className="flex flex-col gap-0.5">
              {tasks.map((task) => (
                <SortableTaskRow
                  key={task.id}
                  task={task}
                  token={token}
                  onRefresh={onRefresh}
                />
              ))}
            </div>
          </SortableContext>

          {isEmpty && (
            <p className="text-xs text-gray-400 dark:text-gray-500 px-3 py-1.5 italic">
              No tasks in this section
            </p>
          )}

          <QuickAddTask
            projectId={projectId}
            sectionId={section.id === '__none__' ? null : section.id}
            token={token}
            onAdded={onRefresh}
          />
        </div>
      )}
    </div>
  )
}

// ─── AddSectionForm ──────────────────────────────────────────────────────────
function AddSectionForm({ projectId, token, onAdded }) {
  const [open, setOpen] = useState(false)
  const [name, setName] = useState('')
  const inputRef = useRef(null)

  const openForm = () => {
    setOpen(true)
    setTimeout(() => inputRef.current?.focus(), 0)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    const trimmed = name.trim()
    if (!trimmed) return
    try {
      const res = await fetch(`${API}/api/sections`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ name: trimmed, project_id: projectId }),
      })
      if (res.ok) {
        setName('')
        setOpen(false)
        onAdded()
      }
    } catch (err) {
      console.error('Add section failed:', err)
    }
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Escape') { setOpen(false); setName('') }
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={openForm}
        className="flex items-center gap-1.5 text-sm text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 px-2 py-1.5 rounded transition-colors mt-2"
      >
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
        Add section
      </button>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="mt-2 px-2">
      <input
        ref={inputRef}
        type="text"
        value={name}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Section name"
        className="w-full text-sm border border-indigo-400 dark:border-indigo-500 rounded-lg px-3 py-1.5 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
      />
      <div className="flex gap-2 mt-2">
        <button
          type="submit"
          className="text-sm px-3 py-1 rounded bg-indigo-600 text-white hover:bg-indigo-700 transition-colors"
        >
          Add section
        </button>
        <button
          type="button"
          onClick={() => { setOpen(false); setName('') }}
          className="text-sm px-3 py-1 rounded text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        >
          Cancel
        </button>
      </div>
    </form>
  )
}

// ─── ProjectView ─────────────────────────────────────────────────────────────
export default function ProjectView({ projectId, token, onBack }) {
  const [project, setProject] = useState(null)
  const [sections, setSections] = useState([])
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  // collapsed state: { [sectionId]: boolean }
  const [collapsedMap, setCollapsedMap] = useState({})

  // active drag item id (for DragOverlay)
  const [activeDragId, setActiveDragId] = useState(null)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } })
  )

  // ── Data fetching ──────────────────────────────────────────────────────────
  const fetchAll = useCallback(async () => {
    if (!projectId || !token) return
    setLoading(true)
    setError(null)
    try {
      const headers = { Authorization: `Bearer ${token}` }
      const [projRes, secRes, taskRes] = await Promise.all([
        fetch(`${API}/api/projects/${projectId}`, { headers }),
        fetch(`${API}/api/sections?project_id=${projectId}`, { headers }),
        fetch(`${API}/api/tasks?project_id=${projectId}&completed=false`, { headers }),
      ])

      if (!projRes.ok) throw new Error('Project not found')

      const projData = await projRes.json()
      const secData = secRes.ok ? await secRes.json() : { sections: [] }
      const taskData = taskRes.ok ? await taskRes.json() : { tasks: [] }

      setProject(projData.project)
      setSections(secData.sections || [])
      setTasks(taskData.tasks || [])
    } catch (err) {
      console.error('ProjectView fetch error:', err)
      setError(err.message || 'Failed to load project')
    } finally {
      setLoading(false)
    }
  }, [projectId, token])

  useEffect(() => {
    fetchAll()
  }, [fetchAll])

  // ── Collapse toggle ────────────────────────────────────────────────────────
  const handleToggleCollapse = useCallback((sectionId) => {
    setCollapsedMap((prev) => ({ ...prev, [sectionId]: !prev[sectionId] }))
  }, [])

  // ── Build grouped data ─────────────────────────────────────────────────────
  // Virtual "no section" bucket has id '__none__'
  const NO_SECTION_ID = '__none__'

  const sectionsWithNone = [
    { id: NO_SECTION_ID, name: 'No Section', sort_order: -1 },
    ...sections,
  ]

  // tasks grouped by section_id (null → NO_SECTION_ID)
  const tasksBySectionId = {}
  for (const s of sectionsWithNone) tasksBySectionId[s.id] = []
  for (const t of tasks) {
    const key = t.section_id || NO_SECTION_ID
    if (tasksBySectionId[key]) {
      tasksBySectionId[key].push(t)
    } else {
      tasksBySectionId[NO_SECTION_ID].push(t)
    }
  }

  // Build a flat lookup: taskId → sectionGroupId
  const taskSectionMap = {}
  for (const [sid, ts] of Object.entries(tasksBySectionId)) {
    for (const t of ts) taskSectionMap[t.id] = sid
  }

  // ── DnD handlers ──────────────────────────────────────────────────────────
  const handleDragStart = ({ active }) => {
    setActiveDragId(active.id)
  }

  const handleDragEnd = useCallback(
    async ({ active, over }) => {
      setActiveDragId(null)
      if (!over || active.id === over.id) return

      const fromSectionId = taskSectionMap[active.id]
      const toSectionId = taskSectionMap[over.id]

      if (!fromSectionId || !toSectionId) return

      const sameSectionMove = fromSectionId === toSectionId

      if (sameSectionMove) {
        // Reorder within the same section (optimistic)
        const sectionTasks = [...tasksBySectionId[fromSectionId]]
        const oldIdx = sectionTasks.findIndex((t) => t.id === active.id)
        const newIdx = sectionTasks.findIndex((t) => t.id === over.id)
        if (oldIdx === -1 || newIdx === -1) return

        const reordered = arrayMove(sectionTasks, oldIdx, newIdx)

        // Optimistic update
        setTasks((prev) => {
          const others = prev.filter((t) => t.section_id !== (fromSectionId === NO_SECTION_ID ? null : fromSectionId) &&
            !(fromSectionId === NO_SECTION_ID && t.section_id === null))
          return [...others, ...reordered]
        })

        // Persist
        const payload = reordered.map((t, i) => ({ id: t.id, sort_order: i }))
        try {
          await fetch(`${API}/api/tasks/reorder`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({ tasks: payload }),
          })
        } catch (err) {
          console.error('Reorder failed:', err)
          fetchAll()
        }
      } else {
        // Cross-section drag: move task to the new section
        const newSectionId = toSectionId === NO_SECTION_ID ? null : toSectionId

        // Optimistic
        setTasks((prev) =>
          prev.map((t) => (t.id === active.id ? { ...t, section_id: newSectionId } : t))
        )

        // Persist via PUT
        try {
          await fetch(`${API}/api/tasks/${active.id}`, {
            method: 'PUT',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({ section_id: newSectionId }),
          })
        } catch (err) {
          console.error('Cross-section move failed:', err)
          fetchAll()
        }
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [token, tasks, sections, fetchAll]
  )

  // ── Render states ──────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (error || !project) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-3">
        <p className="text-sm text-red-500">{error || 'Project not found'}</p>
        {onBack && (
          <button
            type="button"
            onClick={onBack}
            className="text-sm text-indigo-600 hover:underline"
          >
            Go back
          </button>
        )}
      </div>
    )
  }

  const activeTask = activeDragId ? tasks.find((t) => t.id === activeDragId) : null

  // ── Main render ────────────────────────────────────────────────────────────
  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {/* Project header */}
      <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center gap-3">
          {onBack && (
            <button
              type="button"
              onClick={onBack}
              className="p-1.5 rounded hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500 dark:text-gray-400 transition-colors"
              aria-label="Back to projects"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
            </button>
          )}
          <span
            className="w-3 h-3 rounded-full shrink-0"
            style={{ backgroundColor: project.color || '#6366f1' }}
          />
          <h1 className="text-xl font-bold text-gray-900 dark:text-white truncate">
            {project.name}
          </h1>
          <span className="ml-auto text-xs text-gray-400">
            {tasks.length} task{tasks.length !== 1 ? 's' : ''}
          </span>
        </div>
      </div>

      {/* Sections + tasks */}
      <div className="flex-1 px-4 py-4 overflow-y-auto">
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          {sectionsWithNone.map((section) => {
            const sectionTasks = tasksBySectionId[section.id] || []
            const isCollapsed = collapsedMap[section.id] ?? false

            // Skip the "No Section" group if it's empty and there are real sections
            if (section.id === NO_SECTION_ID && sectionTasks.length === 0 && sections.length > 0) {
              return null
            }

            return (
              <SectionGroup
                key={section.id}
                section={section}
                tasks={sectionTasks}
                token={token}
                projectId={projectId}
                onRefresh={fetchAll}
                onToggleCollapse={handleToggleCollapse}
                isCollapsed={isCollapsed}
              />
            )
          })}

          <DragOverlay>
            {activeTask && <TaskGhost task={activeTask} />}
          </DragOverlay>
        </DndContext>

        {/* Add section */}
        <AddSectionForm
          projectId={projectId}
          token={token}
          onAdded={fetchAll}
        />
      </div>
    </div>
  )
}
