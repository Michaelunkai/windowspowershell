import { useState, useEffect, useCallback } from 'react'
import { useParams } from 'react-router-dom'
import { getTasks, createTask, getSections, createSection } from '../api'
import TaskList from '../components/TaskList'
import EmptyState from '../components/EmptyState'
import QuickAddTask from '../components/QuickAddTask'
import ProjectProgress from '../components/ProjectProgress'

export default function ProjectView({ projects, labels, onTaskClick }) {
  const { id } = useParams()
  const projectId = parseInt(id, 10)
  const project = projects.find(p => p.id === projectId)

  const [tasks, setTasks] = useState([])
  const [sections, setSections] = useState([])
  const [loading, setLoading] = useState(true)
  const [showAdd, setShowAdd] = useState(false)
  const [addingSection, setAddingSection] = useState(false)
  const [newSectionName, setNewSectionName] = useState('')
  const [addingTaskSection, setAddingTaskSection] = useState(null)
  const [inlineTitle, setInlineTitle] = useState('')

  const load = useCallback(async () => {
    if (!projectId) return
    setLoading(true)
    try {
      const [tasksRes, sectionsRes] = await Promise.all([
        getTasks({ project_id: projectId }),
        getSections(projectId).catch(() => ({ data: { sections: [] } })),
      ])
      setTasks(tasksRes.data.tasks || [])
      setSections(sectionsRes.data.sections || [])
    } catch {
      setTasks([])
    } finally {
      setLoading(false)
    }
  }, [projectId])

  useEffect(() => { load() }, [load])

  function handleUpdate(updated) {
    setTasks(prev => prev.map(t => t.id === updated.id ? updated : t))
  }

  function handleComplete(taskId) {
    setTasks(prev => prev.filter(t => t.id !== taskId))
  }

  function handleCreated(newTask) {
    setTasks(prev => [...prev, newTask])
  }

  function handleReorder(reordered) {
    setTasks(prev => {
      const subs = prev.filter(t => t.parent_id)
      const withSection = prev.filter(t => t.section_id && !t.parent_id)
      const sectionIds = new Set(reordered.map(t => t.id))
      const rest = withSection.filter(t => !sectionIds.has(t.id))
      return [...reordered, ...rest, ...subs]
    })
  }

  async function handleAddSection(e) {
    e.preventDefault()
    if (!newSectionName.trim()) return
    try {
      const res = await createSection(projectId, { name: newSectionName.trim() })
      setSections(prev => [...prev, res.data.section || res.data])
      setNewSectionName('')
      setAddingSection(false)
    } catch {}
  }

  async function handleInlineTask(e, sectionId) {
    e.preventDefault()
    if (!inlineTitle.trim()) return
    try {
      const res = await createTask({ title: inlineTitle.trim(), project_id: projectId, section_id: sectionId || null })
      handleCreated(res.data.task || res.data)
      setInlineTitle('')
      setAddingTaskSection(null)
    } catch {}
  }

  const activeTasks = tasks.filter(t => !t.is_completed)
  const completedCount = tasks.filter(t => t.is_completed).length

  // Tasks without a section
  const noSectionTasks = activeTasks.filter(t => !t.section_id && !t.parent_id)

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center gap-2">
          {project && (
            <span className="w-3 h-3 rounded-full shrink-0" style={{ backgroundColor: project.color || '#6366f1' }} />
          )}
          <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">
            {project?.name || 'Project'}
          </h1>
        </div>
        <button
          onClick={() => setShowAdd(true)}
          className="text-sm text-red-500 hover:text-red-600 font-medium flex items-center gap-1"
        >
          <span className="text-lg">+</span> Add task
        </button>
      </div>

      {/* Progress bar */}
      {tasks.length > 0 && (
        <div className="mb-5">
          <ProjectProgress completedCount={completedCount} totalCount={tasks.length} />
        </div>
      )}

      {loading ? (
        <div className="text-gray-400 text-sm py-8 text-center">Loading...</div>
      ) : (
        <>
          {/* No-section tasks */}
          {noSectionTasks.length === 0 && sections.length === 0 ? (
            <EmptyState type="projects" />
          ) : (
            <TaskList
              tasks={noSectionTasks}
              onUpdate={handleUpdate}
              onComplete={handleComplete}
              onClick={onTaskClick}
              onReorder={handleReorder}
            />
          )}

          {/* Inline add for no-section */}
          {addingTaskSection === 'none' ? (
            <form onSubmit={e => handleInlineTask(e, null)} className="flex gap-2 items-center mt-2">
              <input
                autoFocus
                type="text"
                value={inlineTitle}
                onChange={e => setInlineTitle(e.target.value)}
                placeholder="Task name"
                className="flex-1 border border-red-400 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none"
                onKeyDown={e => { if (e.key === 'Escape') { setAddingTaskSection(null); setInlineTitle('') } }}
              />
              <button type="submit" className="px-3 py-2 bg-red-500 text-white rounded-lg text-sm hover:bg-red-600">Add</button>
              <button type="button" onClick={() => { setAddingTaskSection(null); setInlineTitle('') }} className="text-sm text-gray-400 hover:text-gray-600 px-2">Cancel</button>
            </form>
          ) : (
            <button
              onClick={() => setAddingTaskSection('none')}
              className="flex items-center gap-2 text-sm text-gray-400 hover:text-red-500 transition-colors py-1 mt-2"
            >
              <span className="text-red-400 text-lg leading-none">+</span>
              Add task
            </button>
          )}

          {/* Sections */}
          {sections.map(section => {
            const sectionTasks = activeTasks.filter(t => t.section_id === section.id && !t.parent_id)
            return (
              <div key={section.id} className="mt-6">
                <h2 className="text-sm font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide mb-2 pb-1 border-b border-gray-200 dark:border-gray-700">
                  {section.name}
                </h2>
                <TaskList
                  tasks={sectionTasks}
                  onUpdate={handleUpdate}
                  onComplete={handleComplete}
                  onClick={onTaskClick}
                  onReorder={reordered => {
                    setTasks(prev => {
                      const other = prev.filter(t => t.section_id !== section.id || t.parent_id)
                      return [...other, ...reordered]
                    })
                  }}
                />
                {addingTaskSection === section.id ? (
                  <form onSubmit={e => handleInlineTask(e, section.id)} className="flex gap-2 items-center mt-2">
                    <input
                      autoFocus
                      type="text"
                      value={inlineTitle}
                      onChange={e => setInlineTitle(e.target.value)}
                      placeholder="Task name"
                      className="flex-1 border border-red-400 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none"
                      onKeyDown={e => { if (e.key === 'Escape') { setAddingTaskSection(null); setInlineTitle('') } }}
                    />
                    <button type="submit" className="px-3 py-2 bg-red-500 text-white rounded-lg text-sm hover:bg-red-600">Add</button>
                    <button type="button" onClick={() => { setAddingTaskSection(null); setInlineTitle('') }} className="text-sm text-gray-400 px-2">Cancel</button>
                  </form>
                ) : (
                  <button
                    onClick={() => { setAddingTaskSection(section.id); setInlineTitle('') }}
                    className="flex items-center gap-2 text-sm text-gray-400 hover:text-red-500 transition-colors py-1 mt-1"
                  >
                    <span className="text-red-400 text-lg leading-none">+</span>
                    Add task
                  </button>
                )}
              </div>
            )
          })}

          {/* Add section */}
          <div className="mt-6">
            {addingSection ? (
              <form onSubmit={handleAddSection} className="flex gap-2 items-center">
                <input
                  autoFocus
                  type="text"
                  value={newSectionName}
                  onChange={e => setNewSectionName(e.target.value)}
                  placeholder="Section name"
                  className="flex-1 border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none"
                  onKeyDown={e => { if (e.key === 'Escape') setAddingSection(false) }}
                />
                <button type="submit" className="px-3 py-2 bg-gray-700 text-white rounded-lg text-sm hover:bg-gray-800">Add</button>
                <button type="button" onClick={() => setAddingSection(false)} className="text-sm text-gray-400 px-2">Cancel</button>
              </form>
            ) : (
              <button
                onClick={() => setAddingSection(true)}
                className="flex items-center gap-2 text-sm text-gray-400 hover:text-gray-600 transition-colors py-1"
              >
                <span className="text-gray-400 text-lg leading-none">+</span>
                Add section
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
        defaultProjectId={projectId}
      />
    </div>
  )
}
