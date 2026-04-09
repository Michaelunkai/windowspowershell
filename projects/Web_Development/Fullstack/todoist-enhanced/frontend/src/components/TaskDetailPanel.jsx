import { useState, useEffect } from 'react'
import { updateTask, getComments, addComment, deleteComment } from '../api'
import { DueDatePickerTrigger } from './DueDatePicker'
import PrioritySelector from './PrioritySelector'
import LabelSelector from './LabelSelector'
import { PRIORITIES } from './PrioritySelector'

/**
 * TaskDetailPanel — right drawer showing full task detail.
 * Props:
 *   task       {object|null}
 *   onClose    {fn}
 *   onUpdate   {fn}     (updatedTask) => void
 *   projects   {array}
 *   labels     {array}
 */

function priorityColor(p) {
  const found = PRIORITIES.find(x => x.value === p)
  return found ? found.color : '#808080'
}

export default function TaskDetailPanel({ task, onClose, onUpdate, projects = [], labels = [] }) {
  const [editing, setEditing] = useState(false)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [priority, setPriority] = useState(4)
  const [projectId, setProjectId] = useState('')
  const [selectedLabels, setSelectedLabels] = useState([])
  const [comments, setComments] = useState([])
  const [newComment, setNewComment] = useState('')
  const [saving, setSaving] = useState(false)
  const [commentsLoading, setCommentsLoading] = useState(false)

  useEffect(() => {
    if (task) {
      setTitle(task.title || '')
      setDescription(task.description || '')
      setDueDate(task.due_date ? task.due_date.split('T')[0] : '')
      setPriority(task.priority || 4)
      setProjectId(task.project_id || '')
      setSelectedLabels((task.labels || []).map(l => l.id || l))
      setEditing(false)
      loadComments(task.id)
    }
  }, [task?.id])

  async function loadComments(taskId) {
    setCommentsLoading(true)
    try {
      const res = await getComments(taskId)
      setComments(res.data.comments || [])
    } catch {
      setComments([])
    } finally {
      setCommentsLoading(false)
    }
  }

  async function handleSave() {
    setSaving(true)
    try {
      const res = await updateTask(task.id, {
        title: title.trim(),
        description: description.trim(),
        due_date: dueDate || null,
        priority,
        project_id: projectId || null,
        label_ids: selectedLabels,
      })
      onUpdate && onUpdate(res.data.task || res.data)
      setEditing(false)
    } finally {
      setSaving(false)
    }
  }

  async function handleAddComment(e) {
    e.preventDefault()
    if (!newComment.trim()) return
    try {
      const res = await addComment(task.id, newComment.trim())
      setComments(prev => [...prev, res.data.comment || res.data])
      setNewComment('')
    } catch {}
  }

  async function handleDeleteComment(commentId) {
    await deleteComment(task.id, commentId)
    setComments(prev => prev.filter(c => c.id !== commentId))
  }

  if (!task) return null

  const pColor = priorityColor(priority)

  return (
    <aside className="w-96 shrink-0 border-l border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 h-screen overflow-y-auto flex flex-col">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 dark:border-gray-700 sticky top-0 bg-white dark:bg-gray-800 z-10">
        <h2 className="font-semibold text-base text-gray-800 dark:text-gray-100 truncate">Task Detail</h2>
        <div className="flex gap-2">
          {editing ? (
            <>
              <button
                onClick={handleSave}
                disabled={saving}
                className="text-sm px-3 py-1 bg-red-500 text-white rounded-lg hover:bg-red-600 disabled:opacity-50"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
              <button
                onClick={() => setEditing(false)}
                className="text-sm px-3 py-1 text-gray-500 hover:text-gray-700 rounded-lg"
              >
                Cancel
              </button>
            </>
          ) : (
            <button
              onClick={() => setEditing(true)}
              className="text-sm px-3 py-1 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 rounded-lg border border-gray-200 dark:border-gray-600"
            >
              Edit
            </button>
          )}
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-xl leading-none">×</button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {/* Title */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-1">Title</label>
          {editing ? (
            <input
              autoFocus
              value={title}
              onChange={e => setTitle(e.target.value)}
              className="w-full text-base font-medium border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-400"
            />
          ) : (
            <p className={`text-base font-medium ${task.is_completed ? 'line-through text-gray-400' : 'text-gray-900 dark:text-gray-100'}`}>
              {task.title}
            </p>
          )}
        </div>

        {/* Description */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-1">Description</label>
          {editing ? (
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={3}
              placeholder="Add a description..."
              className="w-full text-sm border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
            />
          ) : (
            <p className="text-sm text-gray-600 dark:text-gray-300 whitespace-pre-wrap">
              {task.description || <span className="italic text-gray-400">No description</span>}
            </p>
          )}
        </div>

        {/* Due Date */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-1">Due Date</label>
          {editing ? (
            <DueDatePickerTrigger value={dueDate} onChange={setDueDate} placeholder="Set due date" />
          ) : (
            <p className="text-sm text-gray-700 dark:text-gray-300">
              {task.due_date ? new Date(task.due_date).toLocaleDateString(undefined, { month: 'long', day: 'numeric', year: 'numeric' }) : <span className="italic text-gray-400">No due date</span>}
            </p>
          )}
        </div>

        {/* Priority */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-1">Priority</label>
          {editing ? (
            <PrioritySelector value={priority} onChange={setPriority} />
          ) : (
            <span className="text-sm font-semibold" style={{ color: pColor }}>
              P{task.priority || 4} — {PRIORITIES.find(p => p.value === (task.priority || 4))?.title || ''}
            </span>
          )}
        </div>

        {/* Project */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-1">Project</label>
          {editing ? (
            <select
              value={projectId}
              onChange={e => setProjectId(e.target.value)}
              className="text-sm border border-gray-300 dark:border-gray-600 rounded-lg px-2 py-1.5 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 w-full"
            >
              <option value="">Inbox</option>
              {projects.filter(p => !p.is_inbox).map(p => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
          ) : (
            <p className="text-sm text-gray-700 dark:text-gray-300">
              {projects.find(p => p.id === task.project_id)?.name || 'Inbox'}
            </p>
          )}
        </div>

        {/* Labels */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-1">Labels</label>
          {editing ? (
            <LabelSelector labels={labels} selected={selectedLabels} onChange={setSelectedLabels} />
          ) : (
            <div className="flex flex-wrap gap-1">
              {(task.labels || []).length === 0
                ? <span className="italic text-sm text-gray-400">No labels</span>
                : (task.labels || []).map(l => (
                  <span
                    key={l.id || l}
                    className="px-2 py-0.5 rounded-full text-xs text-white"
                    style={{ backgroundColor: l.color || '#6366f1' }}
                  >
                    {l.name || l}
                  </span>
                ))
              }
            </div>
          )}
        </div>

        {/* Comments */}
        <div>
          <label className="text-xs font-semibold text-gray-400 uppercase tracking-wide block mb-2">Comments</label>
          <div className="space-y-2 mb-3">
            {commentsLoading ? (
              <p className="text-sm text-gray-400">Loading...</p>
            ) : comments.length === 0 ? (
              <p className="text-sm italic text-gray-400">No comments yet</p>
            ) : (
              comments.map(c => (
                <div key={c.id} className="bg-gray-50 dark:bg-gray-700 rounded-lg px-3 py-2 text-sm group">
                  <p className="text-gray-700 dark:text-gray-300">{c.content}</p>
                  <div className="flex justify-between items-center mt-1">
                    <span className="text-xs text-gray-400">
                      {c.created_at ? new Date(c.created_at).toLocaleDateString() : ''}
                    </span>
                    <button
                      onClick={() => handleDeleteComment(c.id)}
                      className="text-xs text-red-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
          <form onSubmit={handleAddComment} className="flex gap-2">
            <input
              value={newComment}
              onChange={e => setNewComment(e.target.value)}
              placeholder="Add a comment..."
              className="flex-1 text-sm border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-1.5 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-400"
            />
            <button
              type="submit"
              disabled={!newComment.trim()}
              className="text-sm px-3 py-1.5 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50"
            >
              Add
            </button>
          </form>
        </div>
      </div>
    </aside>
  )
}
