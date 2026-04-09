import { useState, useEffect } from 'react'
import { getUpcoming } from '../api'
import TaskItem from './TaskItem'
import EmptyState from './EmptyState'

function toDateOnly(iso) {
  if (!iso) return null
  return iso.split('T')[0]
}

function today() {
  return new Date().toISOString().split('T')[0]
}

function tomorrow() {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  return d.toISOString().split('T')[0]
}

function thisWeekEnd() {
  const d = new Date()
  const day = d.getDay()
  const daysUntilSun = (7 - day) % 7 || 7
  d.setDate(d.getDate() + daysUntilSun)
  return d.toISOString().split('T')[0]
}

function nextWeekEnd() {
  const d = new Date(thisWeekEnd())
  d.setDate(d.getDate() + 7)
  return d.toISOString().split('T')[0]
}

function getBucket(iso) {
  if (!iso) return 'Later'
  const ds = toDateOnly(iso)
  const t = today()
  const tom = tomorrow()
  const tweEnd = thisWeekEnd()
  const nweEnd = nextWeekEnd()
  if (ds === t) return 'Today'
  if (ds === tom) return 'Tomorrow'
  if (ds <= tweEnd) return 'This Week'
  if (ds <= nweEnd) return 'Next Week'
  return 'Later'
}

const BUCKET_ORDER = ['Today', 'Tomorrow', 'This Week', 'Next Week', 'Later']
const BUCKET_COLORS = {
  Today: 'text-green-600 dark:text-green-400',
  Tomorrow: 'text-blue-600 dark:text-blue-400',
  'This Week': 'text-purple-600 dark:text-purple-400',
  'Next Week': 'text-orange-600 dark:text-orange-400',
  Later: 'text-gray-500 dark:text-gray-400',
}
const BUCKET_BG = {
  Today: 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800',
  Tomorrow: 'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800',
  'This Week': 'bg-purple-50 dark:bg-purple-900/20 border-purple-200 dark:border-purple-800',
  'Next Week': 'bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800',
  Later: 'bg-gray-50 dark:bg-gray-800/30 border-gray-200 dark:border-gray-700',
}

/**
 * UpcomingView — tasks grouped by date buckets with color coding.
 */
export default function UpcomingView({ onSelectTask, onTaskUpdate }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    getUpcoming()
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

  // Group by bucket
  const grouped = {}
  active.forEach(t => {
    const bucket = getBucket(t.due_date)
    if (!grouped[bucket]) grouped[bucket] = []
    grouped[bucket].push(t)
  })

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center text-gray-400">
        <span className="animate-pulse">Loading upcoming tasks...</span>
      </div>
    )
  }

  if (active.length === 0) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100 mb-6">Upcoming</h1>
        <EmptyState
          icon="📅"
          title="Nothing upcoming"
          description="You have no scheduled tasks. Add due dates to tasks to see them here."
        />
      </div>
    )
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Upcoming</h1>
        <span className="text-sm text-gray-400">{active.length} scheduled</span>
      </div>

      <div className="space-y-6">
        {BUCKET_ORDER.filter(b => grouped[b]?.length > 0).map(bucket => (
          <div key={bucket}>
            <div className={`flex items-center gap-2 px-3 py-2 rounded-lg border mb-2 ${BUCKET_BG[bucket]}`}>
              <h2 className={`text-sm font-bold uppercase tracking-wide ${BUCKET_COLORS[bucket]}`}>
                {bucket}
              </h2>
              <span className={`text-xs ${BUCKET_COLORS[bucket]} opacity-70`}>
                ({grouped[bucket].length})
              </span>
            </div>
            <div className="space-y-1">
              {grouped[bucket].map(task => (
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
    </div>
  )
}
