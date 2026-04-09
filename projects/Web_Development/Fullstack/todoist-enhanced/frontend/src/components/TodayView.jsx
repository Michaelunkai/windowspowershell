import { useState, useEffect } from 'react'
import { getToday } from '../api'
import TaskItem from './TaskItem'
import EmptyState from './EmptyState'

function toDateOnly(iso) {
  if (!iso) return null
  return iso.split('T')[0]
}

function isOverdue(iso) {
  if (!iso) return false
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const due = new Date(toDateOnly(iso)); due.setHours(0, 0, 0, 0)
  return due < today
}

/**
 * TodayView — tasks due today grouped by project, overdue tasks in red, completed strikethrough.
 */
export default function TodayView({ projects = [], onSelectTask, onTaskUpdate }) {
  const [data, setData] = useState({ overdue: [], today: [] })
  const [loading, setLoading] = useState(true)
  const [showCompleted, setShowCompleted] = useState(false)

  useEffect(() => {
    setLoading(true)
    getToday()
      .then(r => {
        const all = r.data.tasks || []
        const todayStr = new Date().toISOString().split('T')[0]
        const overdue = all.filter(t => !t.is_completed && isOverdue(t.due_date))
        const todayTasks = all.filter(t => !t.is_completed && toDateOnly(t.due_date) === todayStr)
        const completed = all.filter(t => t.is_completed)
        setData({ overdue, today: todayTasks, completed })
      })
      .catch(() => setData({ overdue: [], today: [], completed: [] }))
      .finally(() => setLoading(false))
  }, [])

  function handleUpdate(updated) {
    setData(prev => {
      const update = list => list.map(t => t.id === updated.id ? updated : t)
      return { overdue: update(prev.overdue), today: update(prev.today), completed: update(prev.completed || []) }
    })
    onTaskUpdate && onTaskUpdate(updated)
  }

  function handleComplete(taskId) {
    setData(prev => {
      const all = [...prev.overdue, ...prev.today]
      const completed = all.find(t => t.id === taskId)
      return {
        overdue: prev.overdue.filter(t => t.id !== taskId),
        today: prev.today.filter(t => t.id !== taskId),
        completed: completed ? [...(prev.completed || []), { ...completed, is_completed: true }] : (prev.completed || []),
      }
    })
  }

  // Group today tasks by project
  function groupByProject(tasks) {
    const groups = {}
    tasks.forEach(t => {
      const key = t.project_id || 'inbox'
      if (!groups[key]) groups[key] = []
      groups[key].push(t)
    })
    return groups
  }

  function projectName(id) {
    if (!id || id === 'inbox') return 'Inbox'
    return projects.find(p => p.id === id)?.name || 'Unknown'
  }

  function projectColor(id) {
    if (!id || id === 'inbox') return '#6366f1'
    return projects.find(p => p.id === id)?.color || '#6366f1'
  }

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center text-gray-400">
        <span className="animate-pulse">Loading today's tasks...</span>
      </div>
    )
  }

  const todayGroups = groupByProject(data.today)
  const totalActive = data.overdue.length + data.today.length
  const completed = data.completed || []

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Today</h1>
          <p className="text-sm text-gray-400 mt-0.5">
            {new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}
          </p>
        </div>
        <span className="text-sm text-gray-400">{totalActive} task{totalActive !== 1 ? 's' : ''}</span>
      </div>

      {totalActive === 0 && completed.length === 0 ? (
        <EmptyState
          icon="☀️"
          title="All done for today!"
          description="No tasks due today. Enjoy your day or add something new."
        />
      ) : (
        <>
          {/* Overdue section */}
          {data.overdue.length > 0 && (
            <div className="mb-6">
              <h2 className="text-sm font-semibold text-red-500 uppercase tracking-wide mb-2 flex items-center gap-1">
                <span>⚠</span> Overdue ({data.overdue.length})
              </h2>
              <div className="space-y-1 border-l-2 border-red-300 pl-3">
                {data.overdue.map(task => (
                  <div key={task.id} className="[&_.text-sm]:text-red-700 dark:[&_.text-sm]:text-red-400">
                    <TaskItem
                      task={task}
                      onUpdate={handleUpdate}
                      onComplete={handleComplete}
                      onClick={onSelectTask}
                    />
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Today tasks grouped by project */}
          {Object.entries(todayGroups).map(([projectId, tasks]) => (
            <div key={projectId} className="mb-6">
              <h2 className="text-sm font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full" style={{ backgroundColor: projectColor(projectId) }} />
                {projectName(projectId)}
              </h2>
              <div className="space-y-1">
                {tasks.map(task => (
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
        </>
      )}

      {completed.length > 0 && (
        <div className="mt-4">
          <button
            onClick={() => setShowCompleted(v => !v)}
            className="text-sm text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 flex items-center gap-1"
          >
            <span>{showCompleted ? '▾' : '▸'}</span>
            {completed.length} completed today
          </button>
          {showCompleted && (
            <div className="space-y-1 mt-2 opacity-60">
              {completed.map(task => (
                <TaskItem
                  key={task.id}
                  task={task}
                  onUpdate={handleUpdate}
                  onComplete={() => {}}
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
