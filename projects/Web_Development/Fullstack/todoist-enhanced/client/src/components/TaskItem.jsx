import { useState, useCallback, useRef, useEffect } from 'react'
import { useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import TaskContextMenu from './TaskContextMenu'

// Forward declaration — used recursively for nested sub-tasks

// Checkbox border/bg colors (priority-based, unchecked state)
const PRIORITY_COLORS = {
  1: 'bg-red-500 border-red-500',
  2: 'bg-orange-500 border-orange-500',
  3: 'bg-blue-500 border-blue-500',
  4: 'bg-gray-300 dark:bg-gray-600 border-gray-300 dark:border-gray-600',
}

// Unchecked checkbox border (priority dot colors)
const PRIORITY_BORDER = {
  1: 'border-red-500 hover:border-red-600',
  2: 'border-orange-400 hover:border-orange-500',
  3: 'border-blue-500 hover:border-blue-600',
  4: 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
}

// Small dot color (always visible beside title)
const PRIORITY_DOT = {
  1: 'bg-red-500',
  2: 'bg-orange-400',
  3: 'bg-blue-500',
  4: 'bg-gray-300 dark:bg-gray-600',
}

const PRIORITY_LABELS = { 1: 'P1', 2: 'P2', 3: 'P3', 4: 'P4' }

// Format due_date string (YYYY-MM-DD or ISO) into display info
function formatDueDate(rawDate) {
  if (!rawDate) return null
  try {
    const date = new Date(rawDate.includes('T') ? rawDate : rawDate + 'T00:00:00')
    const now = new Date()
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
    const tomorrow = new Date(today)
    tomorrow.setDate(today.getDate() + 1)
    const d = new Date(date.getFullYear(), date.getMonth(), date.getDate())
    if (d.getTime() === today.getTime()) return { label: 'Today', overdue: false, today: true }
    if (d.getTime() === tomorrow.getTime()) return { label: 'Tomorrow', overdue: false, today: false }
    if (d < today) return {
      label: date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
      overdue: true,
      today: false,
    }
    return {
      label: date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
      overdue: false,
      today: false,
    }
  } catch {
    return { label: rawDate, overdue: false, today: false }
  }
}

/**
 * TaskItem — renders a single task row with right-click context menu support
 * and inline title editing (click title to edit in-place).
 * Supports nested sub-tasks: fetches /api/tasks?parent_id=X on expand.
 *
 * Props:
 *   task             {object}  task data
 *   onEdit           {fn}      (task) => void  — open edit form for this task
 *   onDuplicated     {fn}      (newTask) => void
 *   onMoved          {fn}      (updatedTask) => void
 *   onDeleted        {fn}      (taskId) => void
 *   onToggleComplete {fn}      (task) => void
 *   onInlineUpdated  {fn}      (updatedTask) => void  — called after inline save
 *   depth            {number}  nesting depth — 0 = top-level, 1+ = sub-task
 */
export default function TaskItem({
  task,
  onComplete,
  onEdit,
  onDelete,
  onDuplicated,
  onMoved,
  // backwards-compatible aliases
  onDeleted,
  onToggleComplete,
  onInlineUpdated,
  depth = 0,
  isDragging = false,
  isOverlay = false,
}) {
  const [contextMenu, setContextMenu] = useState(null) // { x, y } or null

  // Resolve prop aliases
  const resolvedToggleComplete = onComplete || onToggleComplete
  const resolvedDelete = onDelete || onDeleted

  // useSortable — provides drag handle props and CSS transform.
  // Disabled when isOverlay=true (overlay clones) or when editing inline.
  const {
    attributes: sortableAttributes,
    listeners: sortableListeners,
    setNodeRef,
    transform,
    transition,
    isDragging: isSortableDragging,
  } = useSortable({
    id: task.id,
    disabled: isOverlay,
  })

  const sortableStyle = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isSortableDragging ? 0.4 : 1,
  }

  const [isEditing, setIsEditing] = useState(false)
  const [editValue, setEditValue] = useState(task.title)
  const [isSaving, setIsSaving] = useState(false)
  const [isCompleting, setIsCompleting] = useState(false) // drives completion animation
  const inputRef = useRef(null)

  // Sub-tasks state
  const [expanded, setExpanded] = useState(false)
  const [subTasks, setSubTasks] = useState([])
  const [loadingSubTasks, setLoadingSubTasks] = useState(false)
  const childCount = task.child_task_count || 0

  const fetchSubTasks = useCallback(async () => {
    setLoadingSubTasks(true)
    try {
      const res = await fetch(
        `http://localhost:3456/api/tasks?parent_id=${task.id}`,
        { credentials: 'include' }
      )
      if (res.ok) {
        const data = await res.json()
        setSubTasks(data.tasks || [])
      }
    } catch (err) {
      console.error('Failed to fetch sub-tasks:', err)
    } finally {
      setLoadingSubTasks(false)
    }
  }, [task.id])

  const handleToggleExpand = useCallback(async (e) => {
    e.stopPropagation()
    const next = !expanded
    setExpanded(next)
    if (next) {
      await fetchSubTasks()
    }
  }, [expanded, fetchSubTasks])

  // Refresh sub-tasks when child count changes (after task edits)
  useEffect(() => {
    if (expanded && childCount > 0) {
      fetchSubTasks()
    }
  }, [childCount]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSubTaskToggleComplete = useCallback(async (subTask) => {
    try {
      await fetch(`http://localhost:3456/api/tasks/${subTask.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ completed: !subTask.completed }),
      })
      await fetchSubTasks()
    } catch (err) {
      console.error('Toggle sub-task complete failed:', err)
    }
  }, [fetchSubTasks])

  const handleSubRefresh = useCallback(async () => {
    await fetchSubTasks()
    resolvedDelete && resolvedDelete()
  }, [fetchSubTasks, resolvedDelete])

  // Keep editValue in sync if task.title changes externally
  useEffect(() => {
    if (!isEditing) {
      setEditValue(task.title)
    }
  }, [task.title, isEditing])

  // Auto-focus input when entering edit mode
  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus()
      inputRef.current.select()
    }
  }, [isEditing])

  const handleContextMenu = useCallback((e) => {
    e.preventDefault()
    setContextMenu({ x: e.clientX, y: e.clientY })
  }, [])

  const closeMenu = useCallback(() => setContextMenu(null), [])

  const startEditing = useCallback((e) => {
    e.stopPropagation()
    setEditValue(task.title)
    setIsEditing(true)
  }, [task.title])

  const cancelEditing = useCallback(() => {
    setIsEditing(false)
    setEditValue(task.title)
  }, [task.title])

  const saveEdit = useCallback(async () => {
    const trimmed = editValue.trim()
    if (!trimmed) {
      cancelEditing()
      return
    }
    if (trimmed === task.title) {
      setIsEditing(false)
      return
    }
    setIsSaving(true)
    try {
      const res = await fetch(`http://localhost:3456/api/tasks/${task.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ title: trimmed }),
      })
      if (res.ok) {
        const updated = await res.json()
        setIsEditing(false)
        onInlineUpdated && onInlineUpdated(updated)
      } else {
        cancelEditing()
      }
    } catch (err) {
      console.error('Inline title save failed:', err)
      cancelEditing()
    } finally {
      setIsSaving(false)
    }
  }, [editValue, task.title, task.id, cancelEditing, onInlineUpdated])

  const handleKeyDown = useCallback((e) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      saveEdit()
    } else if (e.key === 'Escape') {
      e.preventDefault()
      cancelEditing()
    }
  }, [saveEdit, cancelEditing])

  /**
   * handleComplete — triggers completion animation (strikethrough + fade-out)
   * for 500ms before delegating to onToggleComplete.
   * When marking incomplete we skip the animation and call directly.
   */
  const handleComplete = useCallback(() => {
    if (!resolvedToggleComplete) return
    if (task.completed) {
      // Marking incomplete — no animation needed
      resolvedToggleComplete(task)
      return
    }
    // Marking complete — play animation first, then notify parent
    setIsCompleting(true)
    setTimeout(() => {
      setIsCompleting(false)
      resolvedToggleComplete(task)
    }, 500)
  }, [task, resolvedToggleComplete])

  const priorityColor = PRIORITY_COLORS[task.priority] || PRIORITY_COLORS[4]
  const priorityDotClass = PRIORITY_DOT[task.priority] || PRIORITY_DOT[4]
  const priorityLabel = PRIORITY_LABELS[task.priority] || 'P4'
  const labels = Array.isArray(task.labels) ? task.labels : []
  const commentCount = typeof task.comment_count === 'number' ? task.comment_count : 0
  const dueDateInfo = task.due_date ? formatDueDate(task.due_date) : null
  const isVisuallyCompleted = task.completed || isCompleting

  // Indentation: 32px per depth level (pl-8 = 2rem = 32px in Tailwind)
  const indentStyle = depth > 0 ? { paddingLeft: `${depth * 2}rem` } : {}

  return (
    <>
      <div
        ref={setNodeRef}
        style={{ ...indentStyle, ...sortableStyle }}
        className={isCompleting ? 'task-completing' : undefined}
      >
        <div
          onContextMenu={handleContextMenu}
          className={[
            'group flex items-start gap-2 px-3 py-2.5 rounded-lg cursor-default select-none',
            'hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors',
            task.completed ? 'opacity-50' : '',
          ].join(' ')}
          role="listitem"
          aria-label={task.title}
        >
          {/* Expand/collapse arrow for tasks with child tasks */}
          <div className="flex-shrink-0 w-4 h-5 flex items-center justify-center mt-0.5">
            {childCount > 0 && (
              <button
                type="button"
                aria-label={expanded ? 'Collapse sub-tasks' : 'Expand sub-tasks'}
                onClick={handleToggleExpand}
                className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 focus:outline-none"
                style={{
                  transform: expanded ? 'rotate(90deg)' : 'rotate(0deg)',
                  transition: 'transform 0.15s ease',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M7.293 4.707a1 1 0 011.414 0l5 5a1 1 0 010 1.414l-5 5a1 1 0 01-1.414-1.414L11.586 10 7.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            )}
          </div>

          {/* Drag handle — grip icon, shown on hover for top-level sortable tasks */}
          {!isEditing && !isOverlay && depth === 0 && (
            <button
              type="button"
              aria-label="Drag to reorder"
              {...sortableAttributes}
              {...sortableListeners}
              className="flex-shrink-0 mt-1 opacity-0 group-hover:opacity-40 hover:!opacity-100 cursor-grab active:cursor-grabbing p-0.5 rounded text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 focus:outline-none focus:opacity-100 touch-none"
              tabIndex={-1}
            >
              <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path d="M8 6a2 2 0 110-4 2 2 0 010 4zm0 8a2 2 0 110-4 2 2 0 010 4zm0 8a2 2 0 110-4 2 2 0 010 4zm8-16a2 2 0 110-4 2 2 0 010 4zm0 8a2 2 0 110-4 2 2 0 010 4zm0 8a2 2 0 110-4 2 2 0 010 4z" />
              </svg>
            </button>
          )}

          {/* Completion checkbox */}
          <button
            type="button"
            aria-label={task.completed ? 'Mark incomplete' : 'Mark complete'}
            onClick={handleComplete}
            className={[
              'mt-0.5 flex-shrink-0 w-5 h-5 rounded-full border-2 flex items-center justify-center focus:outline-none focus:ring-2 focus:ring-offset-1',
              'transition-colors duration-300',
              task.completed
                ? 'bg-green-500 border-green-500'
                : isCompleting
                  ? 'bg-green-500 border-green-500 task-checkbox-completing'
                  : priorityColor,
            ].join(' ')}
          >
            {(task.completed || isCompleting) && (
              <svg className="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
              </svg>
            )}
          </button>

        {/* Task content */}
        <div className="flex-1 min-w-0">
          {isEditing ? (
            /* Inline editor */
            <div className="flex items-center gap-2">
              <input
                ref={inputRef}
                type="text"
                value={editValue}
                onChange={(e) => setEditValue(e.target.value)}
                onKeyDown={handleKeyDown}
                disabled={isSaving}
                aria-label="Edit task title"
                className={[
                  'flex-1 text-sm px-2 py-0.5 rounded border',
                  'bg-white dark:bg-gray-900 text-gray-900 dark:text-white',
                  'border-blue-400 dark:border-blue-500 outline-none',
                  'focus:ring-2 focus:ring-blue-400 dark:focus:ring-blue-500',
                  isSaving ? 'opacity-60 cursor-not-allowed' : '',
                ].join(' ')}
              />
              <button
                type="button"
                onClick={saveEdit}
                disabled={isSaving}
                aria-label="Save task title"
                className="flex-shrink-0 px-2 py-0.5 text-xs font-medium rounded bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-blue-400 transition-colors"
              >
                {isSaving ? '...' : 'Save'}
              </button>
              <button
                type="button"
                onClick={cancelEditing}
                disabled={isSaving}
                aria-label="Cancel editing"
                className="flex-shrink-0 px-2 py-0.5 text-xs font-medium rounded bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-gray-400 transition-colors"
              >
                Cancel
              </button>
            </div>
          ) : (
            /* Normal title display — priority dot + click-to-edit */
            <div className="flex items-center gap-1.5">
              {/* Priority dot (color-coded) */}
              <span
                className={['flex-shrink-0 w-2 h-2 rounded-full', priorityDotClass].join(' ')}
                aria-label={`Priority ${priorityLabel}`}
                title={`Priority ${priorityLabel}`}
              />
            <p
              role="button"
              tabIndex={0}
              title="Click to edit title"
              onClick={startEditing}
              onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') startEditing(e) }}
              className={[
                'text-sm leading-snug cursor-text',
                'hover:underline hover:decoration-dotted',
                isVisuallyCompleted ? 'line-through text-gray-400 dark:text-gray-500' : 'text-gray-900 dark:text-white',
                isCompleting ? 'task-title-completing' : '',
              ].join(' ')}
            >
              {task.title}
              {task.pomodoros_done > 0 && (
                <span className="ml-1.5 text-sm" title={`${task.pomodoros_done} pomodoro${task.pomodoros_done !== 1 ? 's' : ''} completed`} aria-label={`${task.pomodoros_done} pomodoros done`}>
                  {'🍅'.repeat(Math.min(task.pomodoros_done, 5))}
                </span>
              )}
              {/* Sub-task count badge */}
              {childCount > 0 && (
                <span
                  onClick={(e) => { e.stopPropagation(); handleToggleExpand(e) }}
                  className="ml-2 inline-flex items-center gap-0.5 text-xs font-medium px-1.5 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 cursor-pointer hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors align-middle"
                  title={`${childCount} sub-task${childCount !== 1 ? 's' : ''} — click to ${expanded ? 'collapse' : 'expand'}`}
                >
                  <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                  </svg>
                  {childCount}
                </span>
              )}
            </p>
            </div>
          )}
          {task.description && (
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 ml-3.5 truncate">
              {task.description}
            </p>
          )}
          {/* ── Meta row: due date chip, recurring, priority badge, label pills, comment badge ── */}
          <div className="flex items-center gap-1.5 mt-1 ml-3.5 flex-wrap">
            {/* Due date chip — color-coded */}
            {dueDateInfo && (
              <span
                className={[
                  'inline-flex items-center gap-1 text-xs px-1.5 py-0.5 rounded font-medium',
                  dueDateInfo.overdue
                    ? 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400'
                    : dueDateInfo.today
                      ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                      : 'bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400',
                ].join(' ')}
                aria-label={`Due: ${dueDateInfo.label}`}
              >
                <svg className="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                {dueDateInfo.label}
              </span>
            )}
            {task.recurring && (
              <span
                className="text-xs text-green-600 dark:text-green-400 flex items-center gap-0.5 font-medium"
                title={String('Recurring: ' + task.recurring)}
                aria-label={String('Recurring task: ' + task.recurring)}
              >
                <span aria-hidden="true">↻</span>
                {task.recurring.startsWith('custom:')
                  ? task.recurring.slice(7) || 'custom'
                  : task.recurring}
              </span>
            )}
            {task.priority && task.priority !== 4 && (
              <span className={[
                'text-xs font-semibold px-1.5 py-0.5 rounded',
                task.priority === 1 ? 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400' :
                task.priority === 2 ? 'bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400' :
                'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400',
              ].join(' ')}>
                {priorityLabel}
              </span>
            )}
            {/* Label pills */}
            {labels.map((label) => (
              <span
                key={label.id}
                className="inline-flex items-center text-xs px-1.5 py-0.5 rounded-full font-medium text-white"
                style={{ backgroundColor: label.color || '#808080' }}
                title={label.name}
                aria-label={`Label: ${label.name}`}
              >
                {label.name}
              </span>
            ))}
            {/* Comment count badge */}
            {commentCount > 0 && (
              <span
                className="inline-flex items-center gap-0.5 text-xs text-gray-400 dark:text-gray-500"
                aria-label={`${commentCount} comment${commentCount !== 1 ? 's' : ''}`}
                title={`${commentCount} comment${commentCount !== 1 ? 's' : ''}`}
              >
                <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                    d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                {commentCount}
              </span>
            )}
          </div>
        </div>

          {/* More options button (visible on hover, hidden while editing) */}
          {!isEditing && (
            <button
              type="button"
              aria-label="Task options"
              onClick={(e) => {
                e.stopPropagation()
                setContextMenu({ x: e.clientX, y: e.clientY })
              }}
              className="flex-shrink-0 opacity-0 group-hover:opacity-100 p-1 rounded text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700 transition-all focus:outline-none focus:opacity-100"
            >
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 8a1.5 1.5 0 110-3 1.5 1.5 0 010 3zm0 5.5a1.5 1.5 0 110-3 1.5 1.5 0 010 3zM10.5 17a1.5 1.5 0 103 0 1.5 1.5 0 00-3 0z" />
              </svg>
            </button>
          )}
        </div>

        {/* Nested sub-tasks — shown when expanded */}
        {expanded && (
          <div className="border-l-2 border-gray-100 dark:border-gray-700 ml-8">
            {loadingSubTasks ? (
              <div className="pl-4 py-2 text-xs text-gray-400 dark:text-gray-500">Loading sub-tasks...</div>
            ) : subTasks.length === 0 ? (
              <div className="pl-4 py-2 text-xs text-gray-400 dark:text-gray-500">No sub-tasks found.</div>
            ) : (
              subTasks.map((subTask) => (
                <TaskItem
                  key={subTask.id}
                  task={subTask}
                  onEdit={onEdit}
                  onDuplicated={onDuplicated}
                  onMoved={onMoved}
                  onDeleted={handleSubRefresh}
                  onToggleComplete={handleSubTaskToggleComplete}
                  onInlineUpdated={fetchSubTasks}
                  depth={depth + 1}
                />
              ))
            )}
          </div>
        )}
      </div>

      {contextMenu && (
        <TaskContextMenu
          task={task}
          x={contextMenu.x}
          y={contextMenu.y}
          onClose={closeMenu}
          onEdit={onEdit}
          onDuplicate={onDuplicated}
          onMoved={onMoved}
          onDelete={resolvedDelete}
        />
      )}
    </>
  )
}
