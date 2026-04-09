import { useState, useEffect, useCallback } from 'react'
import { getInbox, createTask } from '../api'
import TaskList from '../components/TaskList'
import EmptyState from '../components/EmptyState'
import QuickAddTask from '../components/QuickAddTask'

export default function InboxView({ projects, labels, onTaskClick }) {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [showAdd, setShowAdd] = useState(false)
  const [addInline, setAddInline] = useState(false)
  const [inlineTitle, setInlineTitle] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await getInbox()
      setTasks(res.data.tasks || [])
    } catch {
      setTasks([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  function handleUpdate(updatedTask) {
    setTasks(prev => prev.map(t => t.id === updatedTask.id ? updatedTask : t))
  }

  function handleComplete(taskId) {
    setTasks(prev => prev.filter(t => t.id !== taskId))
  }

  function handleCreated(newTask) {
    setTasks(prev => [...prev, newTask])
    load()
  }

  function handleReorder(reordered) {
    setTasks(prev => {
      const subTasks = prev.filter(t => t.parent_id)
      return [...reordered, ...subTasks]
    })
  }

  async function handleInlineAdd(e) {
    e.preventDefault()
    if (!inlineTitle.trim()) return
    try {
      const res = await createTask({ title: inlineTitle.trim() })
      handleCreated(res.data.task || res.data)
      setInlineTitle('')
      setAddInline(false)
    } catch {}
  }

  const activeTasks = tasks.filter(t => !t.is_completed)

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Inbox</h1>
        <button
          onClick={() => setShowAdd(true)}
          className="text-sm text-red-500 hover:text-red-600 font-medium flex items-center gap-1"
        >
          <span className="text-lg">+</span> Add task
        </button>
      </div>

      {loading ? (
        <div className="text-gray-400 text-sm py-8 text-center">Loading...</div>
      ) : activeTasks.length === 0 && !addInline ? (
        <>
          <EmptyState type="inbox" />
          <div className="mt-4 text-center">
            <button
              onClick={() => setAddInline(true)}
              className="text-sm text-gray-400 hover:text-red-500 transition-colors"
            >
              + Add a task
            </button>
          </div>
        </>
      ) : (
        <>
          <TaskList
            tasks={activeTasks}
            onUpdate={handleUpdate}
            onComplete={handleComplete}
            onClick={onTaskClick}
            onReorder={handleReorder}
          />
          <div className="mt-3">
            {addInline ? (
              <form onSubmit={handleInlineAdd} className="flex gap-2 items-center">
                <input
                  autoFocus
                  type="text"
                  value={inlineTitle}
                  onChange={e => setInlineTitle(e.target.value)}
                  placeholder="Task name"
                  className="flex-1 border border-red-400 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none"
                  onKeyDown={e => { if (e.key === 'Escape') { setAddInline(false); setInlineTitle('') } }}
                />
                <button type="submit" className="px-3 py-2 bg-red-500 text-white rounded-lg text-sm hover:bg-red-600">Add</button>
                <button type="button" onClick={() => { setAddInline(false); setInlineTitle('') }} className="text-sm text-gray-400 hover:text-gray-600 px-2">Cancel</button>
              </form>
            ) : (
              <button
                onClick={() => setAddInline(true)}
                className="flex items-center gap-2 text-sm text-gray-400 hover:text-red-500 transition-colors py-1"
              >
                <span className="text-red-400 text-lg leading-none">+</span>
                Add task
              </button>
            )}
          </div>
        </>
      )}

      <QuickAddTask
        open={showAdd}
        onClose={() => setShowAdd(false)}
        onCreated={handleCreated}
        projects={projects}
        labels={labels}
      />
    </div>
  )
}
