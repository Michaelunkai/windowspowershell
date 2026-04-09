import { useState, useEffect, useRef } from 'react'
import { createTask } from '../api'
import { DueDatePickerTrigger } from './DueDatePicker'
import PrioritySelector from './PrioritySelector'
import LabelSelector from './LabelSelector'

/**
 * QuickAddTask — modal triggered by Q key or + button.
 * Props:
 *   open       {boolean}
 *   onClose    {fn}
 *   onCreated  {fn}      (newTask) => void
 *   projects   {array}
 *   labels     {array}
 *   defaultProjectId {number|null}
 */
export default function QuickAddTask({ open, onClose, onCreated, projects = [], labels = [], defaultProjectId = null }) {
  const [title, setTitle] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [priority, setPriority] = useState(4)
  const [projectId, setProjectId] = useState(defaultProjectId || '')
  const [selectedLabels, setSelectedLabels] = useState([])
  const [showLabels, setShowLabels] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const inputRef = useRef(null)

  useEffect(() => {
    if (open) {
      setTitle('')
      setDueDate('')
      setPriority(4)
      setProjectId(defaultProjectId || '')
      setSelectedLabels([])
      setShowLabels(false)
      setError('')
      setTimeout(() => inputRef.current?.focus(), 50)
    }
  }, [open, defaultProjectId])

  useEffect(() => {
    function handleKey(e) {
      if (e.key === 'Escape') onClose && onClose()
    }
    if (open) document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [open, onClose])

  async function handleSubmit(e) {
    e.preventDefault()
    if (!title.trim()) return
    setLoading(true)
    setError('')
    try {
      const res = await createTask({
        title: title.trim(),
        due_date: dueDate || null,
        priority,
        project_id: projectId || null,
        label_ids: selectedLabels,
      })
      onCreated && onCreated(res.data.task || res.data)
      onClose && onClose()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to create task')
    } finally {
      setLoading(false)
    }
  }

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-20 bg-black/40 backdrop-blur-sm"
      onClick={e => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden">
        <form onSubmit={handleSubmit}>
          {/* Title input */}
          <div className="p-4 pb-2">
            <input
              ref={inputRef}
              type="text"
              placeholder="Task name"
              value={title}
              onChange={e => setTitle(e.target.value)}
              className="w-full text-base font-medium bg-transparent border-none outline-none text-gray-900 dark:text-gray-100 placeholder-gray-400"
            />
          </div>

          {/* Options row */}
          <div className="px-4 pb-3 flex flex-wrap gap-2 items-center border-b border-gray-100 dark:border-gray-700">
            <DueDatePickerTrigger value={dueDate} onChange={setDueDate} placeholder="Due date" />

            <div className="shrink-0">
              <PrioritySelector value={priority} onChange={setPriority} />
            </div>

            <select
              value={projectId}
              onChange={e => setProjectId(e.target.value)}
              className="text-sm border border-gray-300 dark:border-gray-600 rounded-lg px-2 py-1.5 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200"
            >
              <option value="">Inbox</option>
              {projects.filter(p => !p.is_inbox).map(p => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>

            <button
              type="button"
              onClick={() => setShowLabels(v => !v)}
              className={`text-sm px-2 py-1.5 rounded-lg border transition-colors
                ${selectedLabels.length > 0
                  ? 'border-indigo-400 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600'
                  : 'border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700'}`}
            >
              # Labels {selectedLabels.length > 0 && `(${selectedLabels.length})`}
            </button>
          </div>

          {/* Label picker */}
          {showLabels && (
            <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700">
              <LabelSelector labels={labels} selected={selectedLabels} onChange={setSelectedLabels} />
            </div>
          )}

          {error && <div className="px-4 py-2 text-red-500 text-sm">{error}</div>}

          {/* Footer buttons */}
          <div className="px-4 py-3 flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!title.trim() || loading}
              className="px-4 py-2 text-sm bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium disabled:opacity-50 transition-colors"
            >
              {loading ? 'Adding...' : 'Add task'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
