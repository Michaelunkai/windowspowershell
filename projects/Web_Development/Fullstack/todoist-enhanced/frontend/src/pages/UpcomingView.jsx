import { useState, useEffect, useCallback } from 'react'
import { getUpcoming } from '../api'
import TaskList from '../components/TaskList'
import EmptyState from '../components/EmptyState'

function groupByDate(tasks) {
  const groups = {}
  tasks.forEach(task => {
    const key = task.due_date ? task.due_date.split('T')[0] : 'No date'
    if (!groups[key]) groups[key] = []
    groups[key].push(task)
  })
  // Sort keys
  const keys = Object.keys(groups).sort((a, b) => {
    if (a === 'No date') return 1
    if (b === 'No date') return -1
    return a.localeCompare(b)
  })
  return keys.map(key => ({ date: key, tasks: groups[key] }))
}

function formatGroupDate(dateStr) {
  if (dateStr === 'No date') return 'No date'
  const [y, m, d] = dateStr.split('-').map(Number)
  const date = new Date(y, m - 1, d)
  return date.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })
}

export default function UpcomingView({ projects, labels, onTaskClick }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await getUpcoming()
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

  const activeTasks = tasks.filter(t => !t.is_completed)
  const groups = groupByDate(activeTasks)

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Upcoming</h1>
        <p className="text-sm text-gray-400 mt-0.5">Tasks with upcoming due dates</p>
      </div>

      {loading ? (
        <div className="text-gray-400 text-sm py-8 text-center">Loading...</div>
      ) : activeTasks.length === 0 ? (
        <EmptyState type="upcoming" />
      ) : (
        <div className="space-y-6">
          {groups.map(group => (
            <div key={group.date}>
              <h2 className="text-sm font-semibold text-gray-500 dark:text-gray-400 mb-2 pb-1 border-b border-gray-100 dark:border-gray-800">
                {formatGroupDate(group.date)}
                <span className="ml-2 text-xs font-normal text-gray-400">
                  {group.tasks.length} task{group.tasks.length !== 1 ? 's' : ''}
                </span>
              </h2>
              <TaskList
                tasks={group.tasks}
                onUpdate={handleUpdate}
                onComplete={handleComplete}
                onClick={onTaskClick}
                onReorder={() => {}}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
