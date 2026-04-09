import { useState, useEffect } from 'react'
import { getTasks } from '../api'
import TaskItem from './TaskItem'
import EmptyState from './EmptyState'
import { PRIORITIES } from './PrioritySelector'

/**
 * PriorityView — tasks sorted by priority P1→P4, with due dates visible.
 */
export default function PriorityView({ onSelectTask, onTaskUpdate }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [filterPriority, setFilterPriority] = useState(null)

  useEffect(() => {
    setLoading(true)
    getTasks({ is_completed: false })
      .then(r => setTasks(r.data.tasks || []))
      .catch(() => setTasks([]))
      .finally(() => setLoading(false))
  }, [])

  function handleUpdate(updated) {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t))
    onTaskUpdate && onTaskUpdate(updated)
  }

  function handleComplete(taskId) {
    setTasks(prev => prev.filter(t => t.id !== taskId))
  }

  const active = tasks.filter(t => !t.is_completed)
  const filtered = filterPriority ? active.filter(t => (t.priority || 4) === filterPriority) : active
  const sorted = [...filtered].sort((a, b) => (a.priority || 4) - (b.priority || 4))

  // Group by priority
  const grouped = { 1: [], 2: [], 3: [], 4: [] }
  sorted.forEach(t => {
    const p = t.priority || 4
    grouped[p].push(t)
  })

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center text-gray-400">
        <span className="animate-pulse">Loading tasks...</span>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Priority</h1>
        <span className="text-sm text-gray-400">{active.length} tasks</span>
      </div>

      {/* Filter pills */}
      <div className="flex gap-2 mb-6 flex-wrap">
        <button
          onClick={() => setFilterPriority(null)}
          className={`px-3 py-1 rounded-full text-sm border font-medium transition-colors
            ${filterPriority === null
              ? 'bg-gray-800 text-white border-gray-800 dark:bg-gray-200 dark:text-gray-800'
              : 'border-gray-300 text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'}`}
        >
          All
        </button>
        {PRIORITIES.map(p => (
          <button
            key={p.value}
            onClick={() => setFilterPriority(filterPriority === p.value ? null : p.value)}
            className="px-3 py-1 rounded-full text-sm border font-medium transition-colors"
            style={{
              borderColor: p.color,
              backgroundColor: filterPriority === p.value ? p.color : 'transparent',
              color: filterPriority === p.value ? '#fff' : p.color,
            }}
          >
            {p.label}
          </button>
        ))}
      </div>

      {sorted.length === 0 ? (
        <EmptyState
          icon="🏳️"
          title="No tasks found"
          description="All tasks are completed or no tasks match the selected priority."
        />
      ) : (
        <div className="space-y-6">
          {PRIORITIES.filter(p => grouped[p.value]?.length > 0 && (!filterPriority || filterPriority === p.value)).map(p => (
            <div key={p.value}>
              <div
                className="flex items-center gap-2 px-3 py-1.5 rounded-lg mb-2"
                style={{ backgroundColor: p.color + '18', borderLeft: `3px solid ${p.color}` }}
              >
                <span className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: p.color }} />
                <h2 className="text-sm font-bold" style={{ color: p.color }}>
                  {p.label} — {p.title}
                </h2>
                <span className="text-xs ml-auto" style={{ color: p.color + 'aa' }}>
                  {grouped[p.value].length} task{grouped[p.value].length !== 1 ? 's' : ''}
                </span>
              </div>
              <div className="space-y-1">
                {grouped[p.value].map(task => (
                  <TaskItem
                    key={task.id}
                    task={task}
                    onUpdate={handleUpdate}
                    onComplete={handleComplete}
                    onClick={onSelectTask}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
