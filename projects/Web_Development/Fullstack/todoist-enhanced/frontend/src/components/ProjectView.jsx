import { useState, useEffect, useCallback } from 'react'
import { useParams } from 'react-router-dom'
import { getTasks, getSections, createSection, updateSection, deleteSection, createTask, updateTask } from '../api'
import TaskItem from './TaskItem'
import EmptyState from './EmptyState'
import QuickAddTask from './QuickAddTask'

/**
 * ProjectView — sections within project, tasks per section, drag-reorder tasks between sections.
 */
export default function ProjectView({ projects = [], labels = [], onSelectTask, onTaskUpdate }) {
  const { id: projectIdStr } = useParams()
  const projectId = Number(projectIdStr)
  const project = projects.find(p => p.id === projectId)

  const [sections, setSections] = useState([])
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [addingSectionId, setAddingSectionId] = useState(null) // section id (or 'new') for adding task inline
  const [newSectionName, setNewSectionName] = useState('')
  const [creatingSection, setCreatingSection] = useState(false)
  const [quickAddOpen, setQuickAddOpen] = useState(false)
  const [draggedTask, setDraggedTask] = useState(null)

  const load = useCallback(() => {
    setLoading(true)
    Promise.all([
      getSections(projectId),
      getTasks({ project_id: projectId }),
    ])
      .then(([secRes, taskRes]) => {
        setSections(secRes.data.sections || [])
        setTasks(taskRes.data.tasks || [])
      })
      .catch(() => {
        setSections([])
        setTasks([])
      })
      .finally(() => setLoading(false))
  }, [projectId])

  useEffect(() => {
    load()
  }, [load])

  function handleUpdate(updated) {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t))
    onTaskUpdate && onTaskUpdate(updated)
  }

  function handleComplete(taskId) {
    setTasks(prev => prev.map(t => t.id === taskId ? { ...t, is_completed: true } : t))
  }

  function handleTaskCreated(task) {
    setTasks(prev => [...prev, task])
  }

  async function handleCreateSection(e) {
    e.preventDefault()
    if (!newSectionName.trim()) return
    setCreatingSection(true)
    try {
      const res = await createSection(projectId, { name: newSectionName.trim() })
      setSections(prev => [...prev, res.data.section || res.data])
      setNewSectionName('')
    } finally {
      setCreatingSection(false)
    }
  }

  // Drag and drop for task reordering between sections
  function handleDragStart(task) {
    setDraggedTask(task)
  }

  async function handleDropOnSection(sectionId) {
    if (!draggedTask) return
    const targetSectionId = sectionId === 'nosection' ? null : sectionId
    if (draggedTask.section_id === targetSectionId) {
      setDraggedTask(null)
      return
    }
    try {
      await updateTask(draggedTask.id, { section_id: targetSectionId })
      setTasks(prev => prev.map(t => t.id === draggedTask.id
        ? { ...t, section_id: targetSectionId }
        : t
      ))
    } catch {}
    setDraggedTask(null)
  }

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center text-gray-400">
        <span className="animate-pulse">Loading project...</span>
      </div>
    )
  }

  if (!project) {
    return (
      <div className="p-6">
        <EmptyState icon="❌" title="Project not found" description="This project may have been deleted." />
      </div>
    )
  }

  const noSectionTasks = tasks.filter(t => !t.section_id && !t.is_completed)
  const completedTasks = tasks.filter(t => t.is_completed)

  return (
    <div className="p-6 max-w-2xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <span className="w-4 h-4 rounded-full shrink-0" style={{ backgroundColor: project.color || '#6366f1' }} />
          <h1 className="text-2xl font-bold text-gray-800 dark:text-gray-100">{project.name}</h1>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setQuickAddOpen(true)}
            className="flex items-center gap-1 px-3 py-1.5 text-sm bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors"
          >
            <span>+</span> Add task
          </button>
        </div>
      </div>

      {/* No-section tasks (drop zone) */}
      <div
        className="mb-6 min-h-[40px] rounded-lg transition-colors"
        onDragOver={e => e.preventDefault()}
        onDrop={() => handleDropOnSection('nosection')}
      >
        {noSectionTasks.length === 0 && tasks.filter(t => !t.section_id).length === 0 && sections.length === 0 ? (
          <EmptyState
            icon="📋"
            title="No tasks yet"
            description="Add your first task to get started."
          />
        ) : (
          <div className="space-y-1">
            {noSectionTasks.map(task => (
              <div
                key={task.id}
                draggable
                onDragStart={() => handleDragStart(task)}
                className="cursor-grab active:cursor-grabbing"
              >
                <TaskItem
                  task={task}
                  onUpdate={handleUpdate}
                  onComplete={handleComplete}
                  onClick={onSelectTask}
                />
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Sections */}
      {sections.map(section => {
        const sectionTasks = tasks.filter(t => t.section_id === section.id && !t.is_completed)
        return (
          <div key={section.id} className="mb-6">
            <div
              className="flex items-center gap-2 mb-2 px-2 py-1.5 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700"
              onDragOver={e => e.preventDefault()}
              onDrop={() => handleDropOnSection(section.id)}
            >
              <h2 className="text-sm font-semibold text-gray-600 dark:text-gray-300 flex-1">{section.name}</h2>
              <span className="text-xs text-gray-400">{sectionTasks.length}</span>
            </div>
            <div className="space-y-1 min-h-[32px] pl-2">
              {sectionTasks.map(task => (
                <div
                  key={task.id}
                  draggable
                  onDragStart={() => handleDragStart(task)}
                  className="cursor-grab active:cursor-grabbing"
                >
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
        )
      })}

      {/* Add section */}
      <form onSubmit={handleCreateSection} className="flex gap-2 mt-2">
        <input
          value={newSectionName}
          onChange={e => setNewSectionName(e.target.value)}
          placeholder="+ Add section"
          className="flex-1 text-sm border-b border-dashed border-gray-300 dark:border-gray-600 bg-transparent px-1 py-1 focus:outline-none focus:border-gray-500 text-gray-600 dark:text-gray-400"
        />
        {newSectionName.trim() && (
          <button
            type="submit"
            disabled={creatingSection}
            className="text-sm px-3 py-1 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50"
          >
            Add
          </button>
        )}
      </form>

      {/* Completed */}
      {completedTasks.length > 0 && (
        <div className="mt-8 border-t border-gray-200 dark:border-gray-700 pt-4">
          <p className="text-sm text-gray-400 mb-2">{completedTasks.length} completed task{completedTasks.length !== 1 ? 's' : ''}</p>
          <div className="space-y-1 opacity-60">
            {completedTasks.map(task => (
              <TaskItem
                key={task.id}
                task={task}
                onUpdate={handleUpdate}
                onComplete={() => {}}
                onClick={onSelectTask}
              />
            ))}
          </div>
        </div>
      )}

      <QuickAddTask
        open={quickAddOpen}
        onClose={() => setQuickAddOpen(false)}
        onCreated={handleTaskCreated}
        projects={projects}
        labels={labels}
        defaultProjectId={projectId}
      />
    </div>
  )
}
