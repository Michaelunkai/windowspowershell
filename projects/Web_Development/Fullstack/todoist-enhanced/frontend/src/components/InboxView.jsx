import { useState, useEffect } from 'react'
import { getInbox } from '../api'
import TaskItem from './TaskItem'
import EmptyState from './EmptyState'

/**
 * InboxView — tasks without project_id, sorted by added_date desc.
 */
export default function InboxView({ labels = [], projects = [], onSelectTask, onTaskUpdate }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [showCompleted, setShowCompleted] = useState(false)

  useEffect(() => {
    setLoading(true)
    getInbox()
      .then(r => setTasks(r.data.tasks || []))
      .catch(() => setTasks([]))
      .finally(() => setLoading(false))
  }, [])

  function handleUpdate(updated) {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t))
    onTaskUpdate && onTaskUpdate(updated)
  }

  function handleComplete(taskId) {
    setTasks(prev => prev.map(t => t.id === taskId ? { ...t, is_completed: true } : t))
  }

  const active = tasks.filter(t => !t.is_completed)
  const completed = tasks.filter(t => t.is_completed)

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center text-gray-400">
        <span className="animate-pulse">Loading inbox...</span>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Inbox</h1>
        <span className="text-sm text-gray-400">{active.length} task{active.length !== 1 ? 's' : ''}</span>
      </div>

      {active.length === 0 && completed.length === 0 ? (
        <EmptyState
          icon="📥"
          title="Your inbox is empty"
          description="Tasks without a project will appear here."
        />
      ) : (
        <div className="space-y-1">
          {active.map(task => (
            <TaskItem
              key={task.id}
              task={task}
              onUpdate={handleUpdate}
              onComplete={handleComplete}
              onClick={onSelectTask}
            />
          ))}
        </div>
      )}

      {completed.length > 0 && (
        <div className="mt-6">
          <button
            onClick={() => setShowCompleted(v => !v)}
            className="text-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 flex items-center gap-1"
          >
            <span>{showCompleted ? '▾' : '▸'}</span>
            {completed.length} completed
          </button>
          {showCompleted && (
            <div className="space-y-1 mt-2 opacity-60">
              {completed.map(task => (
                <TaskItem
                  key={task.id}
                  task={task}
                  onUpdate={handleUpdate}
                  onComplete={handleComplete}
                  onClick={onSelectTask}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
