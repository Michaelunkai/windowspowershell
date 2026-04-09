import { useState, useEffect, useCallback } from 'react'
import { getToday } from '../api'
import TaskList from '../components/TaskList'
import EmptyState from '../components/EmptyState'

export default function TodayView({ projects, labels, onTaskClick }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await getToday()
      setTasks(res.data.tasks || [])
    } catch {
      setTasks([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  function handleUpdate(updated) {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t))
  }

  function handleComplete(id) {
    setTasks(prev => prev.filter(t => t.id !== id))
  }

  function handleReorder(reordered) {
    setTasks(prev => {
      const subs = prev.filter(t => t.parent_id)
      return [...reordered, ...subs]
    })
  }

  const today = new Date()
  const dateStr = today.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })
  const activeTasks = tasks.filter(t => !t.is_completed)
  const completedTasks = tasks.filter(t => t.is_completed)

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Today</h1>
        <p className="text-sm text-gray-400 mt-0.5">{dateStr}</p>
      </div>

      {loading ? (
        <div className="text-gray-400 text-sm py-8 text-center">Loading...</div>
      ) : activeTasks.length === 0 ? (
        <EmptyState type="today" />
      ) : (
        <TaskList
          tasks={activeTasks}
          onUpdate={handleUpdate}
          onComplete={handleComplete}
          onClick={onTaskClick}
          onReorder={handleReorder}
        />
      )}

      {/* Completed section */}
      {completedTasks.length > 0 && (
        <div className="mt-6">
          <h2 className="text-sm font-semibold text-gray-400 dark:text-gray-500 uppercase tracking-wide mb-2">
            Completed ({completedTasks.length})
          </h2>
          <div className="space-y-0.5 opacity-60">
            {completedTasks.map(task => (
              <div key={task.id} className="flex items-center gap-3 px-3 py-2">
                <span className="w-4 h-4 rounded-full bg-gray-300 flex items-center justify-center shrink-0">
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                    <path d="M2 5l2.5 2.5L8 3" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/>
                  </svg>
                </span>
                <span className="text-sm text-gray-400 line-through">{task.title}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
