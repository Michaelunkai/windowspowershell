import { useState, useEffect } from 'react'
import { getTasks } from '../api'
import TaskList from '../components/TaskList'

const PRIORITY_LABELS = { 1: 'Priority 1', 2: 'Priority 2', 3: 'Priority 3', 4: 'Priority 4' }
const PRIORITY_COLORS = { 1: '#DB4035', 2: '#FF9933', 3: '#4073FF', 4: '#808080' }

export default function FiltersView({ labels, onTaskClick }) {
  const [tasks, setTasks] = useState([])
  const [activeLabel, setActiveLabel] = useState(null)
  const [activePriority, setActivePriority] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      setLoading(true)
      try {
        const res = await getTasks({})
        setTasks(res.data.tasks || [])
      } catch {
        setTasks([])
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  function handleUpdate(updated) {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t))
  }

  function handleComplete(id) {
    setTasks(prev => prev.filter(t => t.id !== id))
  }

  const activeTasks = tasks.filter(t => !t.is_completed)

  let filtered = activeTasks
  if (activeLabel) {
    filtered = filtered.filter(t => t.labels?.some(l => l.id === activeLabel))
  }
  if (activePriority) {
    filtered = filtered.filter(t => (t.priority || 4) === activePriority)
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-4">Filters &amp; Labels</h1>

      {/* Priority filters */}
      <div className="mb-4">
        <h2 className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">By Priority</h2>
        <div className="flex flex-wrap gap-2">
          {[1, 2, 3, 4].map(p => (
            <button
              key={p}
              onClick={() => setActivePriority(activePriority === p ? null : p)}
              className="px-3 py-1.5 rounded-full text-sm font-medium border transition-all"
              style={{
                borderColor: PRIORITY_COLORS[p],
                backgroundColor: activePriority === p ? PRIORITY_COLORS[p] : 'transparent',
                color: activePriority === p ? '#fff' : PRIORITY_COLORS[p],
              }}
            >
              {PRIORITY_LABELS[p]}
            </button>
          ))}
        </div>
      </div>

      {/* Label filters */}
      {labels.length > 0 && (
        <div className="mb-5">
          <h2 className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">By Label</h2>
          <div className="flex flex-wrap gap-2">
            {labels.map(l => (
              <button
                key={l.id}
                onClick={() => setActiveLabel(activeLabel === l.id ? null : l.id)}
                className="px-3 py-1.5 rounded-full text-sm font-medium text-white transition-all"
                style={{
                  backgroundColor: l.color || '#6366f1',
                  opacity: activeLabel && activeLabel !== l.id ? 0.4 : 1,
                  outline: activeLabel === l.id ? '2px solid #1F1F1F' : 'none',
                  outlineOffset: '2px',
                }}
              >
                {l.name}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Task list */}
      {(activeLabel || activePriority) && (
        <div>
          <h2 className="text-sm font-semibold text-gray-600 dark:text-gray-400 mb-2">
            {filtered.length} task{filtered.length !== 1 ? 's' : ''}
          </h2>
          {loading ? (
            <div className="text-gray-400 text-sm py-4 text-center">Loading...</div>
          ) : (
            <TaskList
              tasks={filtered}
              onUpdate={handleUpdate}
              onComplete={handleComplete}
              onClick={onTaskClick}
              onReorder={() => {}}
            />
          )}
        </div>
      )}

      {!activeLabel && !activePriority && (
        <p className="text-sm text-gray-400 mt-4">Select a filter above to view matching tasks.</p>
      )}
    </div>
  )
}
