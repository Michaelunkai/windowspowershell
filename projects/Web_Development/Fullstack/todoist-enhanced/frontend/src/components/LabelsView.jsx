import { useState, useEffect } from 'react'
import { getTasks } from '../api'
import TaskItem from './TaskItem'
import EmptyState from './EmptyState'

/**
 * LabelsView — clickable label pills, filter tasks by label, multi-label filtering.
 */
export default function LabelsView({ labels = [], onSelectTask, onTaskUpdate }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [selectedLabels, setSelectedLabels] = useState([])

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

  function toggleLabel(labelId) {
    setSelectedLabels(prev =>
      prev.includes(labelId) ? prev.filter(id => id !== labelId) : [...prev, labelId]
    )
  }

  const active = tasks.filter(t => !t.is_completed)

  // Filter by selected labels (AND logic: task must have ALL selected labels)
  const filtered = selectedLabels.length === 0
    ? active
    : active.filter(t => {
        const taskLabelIds = (t.labels || []).map(l => l.id || l)
        return selectedLabels.every(id => taskLabelIds.includes(id))
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
        <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">Labels</h1>
        <span className="text-sm text-gray-400">{filtered.length} tasks</span>
      </div>

      {/* Label pills */}
      {labels.length > 0 ? (
        <div className="flex flex-wrap gap-2 mb-6">
          {labels.map(label => {
            const isSelected = selectedLabels.includes(label.id)
            return (
              <button
                key={label.id}
                onClick={() => toggleLabel(label.id)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium border-2 transition-all"
                style={{
                  borderColor: label.color || '#6366f1',
                  backgroundColor: isSelected ? (label.color || '#6366f1') : 'transparent',
                  color: isSelected ? '#fff' : (label.color || '#6366f1'),
                }}
              >
                <span className="w-2 h-2 rounded-full" style={{ backgroundColor: isSelected ? '#ffffff88' : (label.color || '#6366f1') }} />
                {label.name}
                {isSelected && (
                  <span className="ml-0.5 opacity-70">×</span>
                )}
              </button>
            )
          })}
          {selectedLabels.length > 0 && (
            <button
              onClick={() => setSelectedLabels([])}
              className="px-3 py-1.5 rounded-full text-sm text-gray-500 border border-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800"
            >
              Clear filters
            </button>
          )}
        </div>
      ) : (
        <div className="mb-6 text-sm text-gray-400 italic">No labels created yet.</div>
      )}

      {/* Task list */}
      {filtered.length === 0 ? (
        <EmptyState
          icon="🏷️"
          title={selectedLabels.length > 0 ? 'No tasks match selected labels' : 'No tasks found'}
          description={selectedLabels.length > 0
            ? 'Try selecting fewer labels or clearing the filter.'
            : 'Create tasks and assign labels to see them here.'}
        />
      ) : (
        <div className="space-y-1">
          {filtered.map(task => (
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
  )
}
