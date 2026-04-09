import { useState } from 'react'
import { completeTask, uncompleteTask, updateTask } from '../api'
import { PRIORITIES } from './PrioritySelector'

/**
 * TaskItem — single task row with checkbox, priority dot, title, due date, labels.
 * Props:
 *   task       {object}   task data
 *   onUpdate   {fn}       (updatedTask) => void
 *   onComplete {fn}       (taskId) => void
 *   onClick    {fn}       (task) => void — open detail panel
 */

function priorityColor(p) {
  const found = PRIORITIES.find(x => x.value === p)
  return found ? found.color : '#808080'
}

function formatDate(iso) {
  if (!iso) return null
  const [y, m, d] = iso.split('T')[0].split('-').map(Number)
  const date = new Date(y, m - 1, d)
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

function isOverdue(iso) {
  if (!iso) return false
  const today = new Date(); today.setHours(0,0,0,0)
  const due = new Date(iso.split('T')[0]); due.setHours(0,0,0,0)
  return due < today
}

function isTodayDate(iso) {
  if (!iso) return false
  const today = new Date(); today.setHours(0,0,0,0)
  const due = new Date(iso.split('T')[0]); due.setHours(0,0,0,0)
  return due.getTime() === today.getTime()
}

export default function TaskItem({ task, onUpdate, onComplete, onClick }) {
  const [loading, setLoading] = useState(false)
  const [completing, setCompleting] = useState(false)
  const [editing, setEditing] = useState(false)
  const [editTitle, setEditTitle] = useState(task.title)
  const [hovered, setHovered] = useState(false)

  async function handleToggle(e) {
    e.stopPropagation()
    if (loading) return
    setLoading(true)
    try {
      if (task.is_completed) {
        await uncompleteTask(task.id)
        onUpdate && onUpdate({ ...task, is_completed: false })
      } else {
        setCompleting(true)
        await completeTask(task.id)
        // Let animation play before removing from list
        setTimeout(() => {
          setCompleting(false)
          onComplete && onComplete(task.id)
          onUpdate && onUpdate({ ...task, is_completed: true })
        }, 380)
      }
    } finally {
      setLoading(false)
    }
  }

  async function handleSaveEdit() {
    if (!editTitle.trim()) return
    try {
      await updateTask(task.id, { title: editTitle.trim() })
      onUpdate && onUpdate({ ...task, title: editTitle.trim() })
      setEditing(false)
    } catch {}
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter') handleSaveEdit()
    if (e.key === 'Escape') { setEditTitle(task.title); setEditing(false) }
  }

  const overdue = isOverdue(task.due_date) && !task.is_completed
  const todayDue = isTodayDate(task.due_date)
  const pColor = priorityColor(task.priority || 4)
  const subtaskCount = task.subtasks_count || task.sub_tasks_count || 0

  return (
    <div
      className={`group flex items-start gap-3 px-3 py-2 rounded-lg cursor-pointer transition-colors
        ${hovered ? 'bg-gray-50 dark:bg-gray-800/60' : ''}
        ${completing ? 'task-completing' : ''}
        ${task.is_completed ? 'opacity-60' : ''}`}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onClick={() => !editing && onClick && onClick(task)}
    >
      {/* Checkbox */}
      <button
        type="button"
        onClick={handleToggle}
        disabled={loading}
        aria-label={task.is_completed ? 'Mark incomplete' : 'Mark complete'}
        className="mt-0.5 shrink-0 focus:outline-none"
      >
        <span
          className={`flex items-center justify-center w-4 h-4 rounded-full border-2 transition-all duration-200
            ${task.is_completed || completing ? 'bg-gray-400 border-gray-400' : 'border-gray-400 hover:border-opacity-80'}`}
          style={!task.is_completed && !completing ? { borderColor: pColor } : {}}
        >
          {(task.is_completed || completing) && (
            <svg width="10" height="10" viewBox="0 0 10 10" fill="none" className="task-check-mark">
              <path d="M2 5l2.5 2.5L8 3" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
          )}
        </span>
      </button>

      {/* Content */}
      <div className="flex-1 min-w-0">
        {editing ? (
          <div className="flex gap-2 items-center" onClick={e => e.stopPropagation()}>
            <input
              autoFocus
              value={editTitle}
              onChange={e => setEditTitle(e.target.value)}
              onKeyDown={handleKeyDown}
              className="flex-1 text-sm border border-blue-400 rounded px-2 py-0.5 bg-white dark:bg-gray-700 dark:text-gray-100 focus:outline-none"
            />
            <button
              onClick={handleSaveEdit}
              className="text-xs bg-blue-500 text-white px-2 py-1 rounded hover:bg-blue-600"
            >Save</button>
            <button
              onClick={() => { setEditTitle(task.title); setEditing(false) }}
              className="text-xs text-gray-500 hover:text-gray-700 px-1"
            >Cancel</button>
          </div>
        ) : (
          <span
            className={`text-sm block ${task.is_completed ? 'line-through text-gray-400' : 'text-gray-800 dark:text-gray-100'} hover:underline`}
            onClick={e => { e.stopPropagation(); setEditTitle(task.title); setEditing(true) }}
            title="Click to edit"
          >
            {task.title}
          </span>
        )}

        {/* Meta row */}
        <div className="flex items-center flex-wrap gap-2 mt-0.5">
          {task.due_date && (
            <span className={`text-xs font-medium ${
              overdue ? 'text-red-500' : todayDue ? 'text-green-600' : 'text-gray-400'
            }`}>
              {overdue ? '⚠ ' : ''}{formatDate(task.due_date)}
            </span>
          )}
          {task.labels && task.labels.map(l => (
            <span
              key={l.id || l}
              className="px-1.5 py-0.5 rounded-full text-xs text-white"
              style={{ backgroundColor: l.color || '#6366f1' }}
            >
              {l.name || l}
            </span>
          ))}
          {subtaskCount > 0 && (
            <span className="text-xs text-gray-400 flex items-center gap-0.5" title={`${subtaskCount} sub-task${subtaskCount !== 1 ? 's' : ''}`}>
              <svg width="11" height="11" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M2 4h12M6 8h8M9 12h5" strokeLinecap="round"/>
              </svg>
              {subtaskCount}
            </span>
          )}
        </div>
      </div>

      {/* Priority dot */}
      <span
        className="mt-1 shrink-0 w-2 h-2 rounded-full"
        style={{ backgroundColor: pColor }}
        title={`Priority ${task.priority || 4}`}
      />
    </div>
  )
}
