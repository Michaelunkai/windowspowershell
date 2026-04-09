import { useState, useEffect, useCallback } from 'react'
import TaskItem from '../components/TaskItem'
import TaskDetailPanel from '../components/TaskDetailPanel'
import EmptyState from '../components/EmptyState'

const API_BASE = 'http://localhost:3456'

/**
 * Groups an array of tasks by project_name.
 * Tasks without a project get grouped under "No Project".
 * Returns an array of { projectName, projectColor, tasks } objects.
 */
function groupByProject(tasks) {
  const map = new Map()
  for (const task of tasks) {
    const key = task.project_name || '__no_project__'
    if (!map.has(key)) {
      map.set(key, {
        projectName: task.project_name || 'No Project',
        projectColor: task.project_color || '#6366f1',
        tasks: [],
      })
    }
    map.get(key).tasks.push(task)
  }
  // Sort groups: named projects first, "No Project" last
  const groups = Array.from(map.values())
  groups.sort((a, b) => {
    if (a.projectName === 'No Project') return 1
    if (b.projectName === 'No Project') return -1
    return a.projectName.localeCompare(b.projectName)
  })
  return groups
}

function formatDate(dateStr) {
  if (!dateStr) return ''
  const [year, month, day] = dateStr.split('-').map(Number)
  const d = new Date(year, month - 1, day)
  return d.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })
}

function SectionHeader({ title, count, color = 'text-gray-700 dark:text-gray-200', accent }) {
  return (
    <div className={`flex items-center gap-2 mb-2 mt-5 first:mt-0 ${color}`}>
      {accent && (
        <span className={`w-2 h-2 rounded-full ${accent}`} aria-hidden="true" />
      )}
      <h2 className="text-sm font-semibold uppercase tracking-wide">
        {title}
      </h2>
      {count > 0 && (
        <span className="ml-auto text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 px-2 py-0.5 rounded-full">
          {count}
        </span>
      )}
    </div>
  )
}

function ProjectGroup({ projectName, projectColor, tasks, onRefresh, isOverdue = false, isCompleted = false }) {
  return (
    <div className="mb-4">
      {/* Project header row */}
      <div className="flex items-center gap-2 mb-1.5 px-1">
        <span
          className="w-2.5 h-2.5 rounded-full shrink-0"
          style={{ backgroundColor: projectColor }}
          aria-hidden="true"
        />
        <span className={`text-xs font-semibold ${isOverdue ? 'text-red-500' : isCompleted ? 'text-gray-400 dark:text-gray-500' : 'text-gray-600 dark:text-gray-300'}`}>
          {projectName}
        </span>
        <span className="text-xs text-gray-400 dark:text-gray-500 ml-auto">
          {tasks.length}
        </span>
      </div>

      {/* Task rows */}
      <div className={`pl-4 ${isCompleted ? 'opacity-60' : ''}`} role="list">
        {tasks.map((task) => (
          <OverridableTaskItem
            key={task.id}
            task={task}
            onRefresh={onRefresh}
            isOverdue={isOverdue}
          />
        ))}
      </div>
    </div>
  )
}

/**
 * Wraps TaskItem but injects overdue red styling and handles toggle/edit inline.
 */
function OverridableTaskItem({ task, onRefresh, isOverdue }) {
  const [editingTask, setEditingTask] = useState(null)

  const handleToggleComplete = useCallback(async (t) => {
    try {
      await fetch(`${API_BASE}/api/tasks/${t.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ completed: !t.completed }),
      })
      onRefresh && onRefresh()
    } catch (err) {
      console.error('Toggle complete failed:', err)
    }
  }, [onRefresh])

  return (
    <>
      <div className={isOverdue && !task.completed ? 'overdue-task-wrapper' : ''}>
        {/* Overdue badge */}
        {isOverdue && task.due_date && (
          <span className="inline-block text-[10px] font-semibold text-red-500 dark:text-red-400 ml-8 mb-0.5 leading-none">
            Overdue &middot; {task.due_date}
          </span>
        )}
        <TaskItem
          task={task}
          onEdit={() => setEditingTask(task)}
          onDuplicated={onRefresh}
          onMoved={onRefresh}
          onDeleted={onRefresh}
          onToggleComplete={handleToggleComplete}
        />
      </div>
      {editingTask && (
        <div className="fixed inset-0 z-50 flex items-start justify-end bg-black/20 dark:bg-black/40" onClick={() => setEditingTask(null)}>
          <div className="w-[350px] h-full" onClick={(e) => e.stopPropagation()}>
            <TaskDetailPanel
              task={editingTask}
              onClose={() => setEditingTask(null)}
              onUpdated={() => {
                setEditingTask(null)
                onRefresh && onRefresh()
              }}
              onDeleted={() => {
                setEditingTask(null)
                onRefresh && onRefresh()
              }}
            />
          </div>
        </div>
      )}
    </>
  )
}

/**
 * TodayView — shows tasks due today grouped by project.
 * - Overdue tasks appear in a separate "Overdue" section with red accents.
 * - Completed tasks are greyed out and shown at the bottom.
 *
 * Fetches from GET /api/views/today which returns:
 *   { tasks, overdue_tasks, completed_tasks, date }
 */
export default function TodayView({ token }) {
  const [todayTasks, setTodayTasks] = useState([])
  const [overdueTasks, setOverdueTasks] = useState([])
  const [completedTasks, setCompletedTasks] = useState([])
  const [date, setDate] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showCompleted, setShowCompleted] = useState(false)

  const fetchData = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const headers = token ? { Authorization: `Bearer ${token}` } : {}
      const res = await fetch(`${API_BASE}/api/views/today`, {
        headers,
        credentials: 'include',
      })
      if (!res.ok) {
        throw new Error(`Failed to load today view (${res.status})`)
      }
      const data = await res.json()
      setTodayTasks(data.tasks || [])
      setOverdueTasks(data.overdue_tasks || [])
      setCompletedTasks(data.completed_tasks || [])
      setDate(data.date || '')
    } catch (err) {
      console.error('TodayView fetch error:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [token])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  // Group tasks by project
  const todayGroups = groupByProject(todayTasks)
  const overdueGroups = groupByProject(overdueTasks)
  const completedGroups = groupByProject(completedTasks)

  const totalToday = todayTasks.length
  const totalOverdue = overdueTasks.length
  const totalCompleted = completedTasks.length
  const totalActive = totalToday + totalOverdue

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <div className="w-6 h-6 border-2 border-red-400 border-t-transparent rounded-full animate-spin" />
        <span className="ml-3 text-sm text-gray-500 dark:text-gray-400">Loading today&hellip;</span>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-center">
        <p className="text-sm text-red-500 mb-3">{error}</p>
        <button
          onClick={fetchData}
          className="text-sm px-4 py-2 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 dark:bg-red-900/20 dark:hover:bg-red-900/40 dark:text-red-400 transition-colors"
        >
          Retry
        </button>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      {/* Page header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Today</h1>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
          {date ? formatDate(date) : ''}
          {totalActive > 0 && (
            <span className="ml-2 font-medium text-gray-700 dark:text-gray-300">
              &mdash; {totalActive} task{totalActive !== 1 ? 's' : ''} remaining
            </span>
          )}
        </p>
      </div>

      {totalActive === 0 && totalCompleted === 0 ? (
        <EmptyState type="today" />
      ) : (
        <>
          {/* ── Overdue section ────────────────────────── */}
          {totalOverdue > 0 && (
            <section aria-label="Overdue tasks">
              <SectionHeader
                title="Overdue"
                count={totalOverdue}
                color="text-red-600 dark:text-red-400"
                accent="bg-red-500"
              />
              {overdueGroups.map(({ projectName, projectColor, tasks }) => (
                <ProjectGroup
                  key={`overdue-${projectName}`}
                  projectName={projectName}
                  projectColor={projectColor}
                  tasks={tasks}
                  onRefresh={fetchData}
                  isOverdue
                />
              ))}
            </section>
          )}

          {/* ── Today section ──────────────────────────── */}
          {totalToday > 0 && (
            <section aria-label="Tasks due today">
              <SectionHeader
                title="Due Today"
                count={totalToday}
                color="text-gray-800 dark:text-gray-100"
              />
              {todayGroups.map(({ projectName, projectColor, tasks }) => (
                <ProjectGroup
                  key={`today-${projectName}`}
                  projectName={projectName}
                  projectColor={projectColor}
                  tasks={tasks}
                  onRefresh={fetchData}
                />
              ))}
            </section>
          )}

          {/* ── Completed section ──────────────────────── */}
          {totalCompleted > 0 && (
            <section aria-label="Completed tasks" className="mt-6">
              <button
                type="button"
                onClick={() => setShowCompleted((v) => !v)}
                className="flex items-center gap-2 text-sm font-semibold text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 transition-colors mb-2 w-full text-left"
                aria-expanded={showCompleted}
              >
                <svg
                  className={`w-3.5 h-3.5 transition-transform ${showCompleted ? 'rotate-90' : ''}`}
                  fill="currentColor"
                  viewBox="0 0 20 20"
                  aria-hidden="true"
                >
                  <path
                    fillRule="evenodd"
                    d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                    clipRule="evenodd"
                  />
                </svg>
                <span className="uppercase tracking-wide text-xs">
                  Completed &mdash; {totalCompleted}
                </span>
              </button>

              {showCompleted && (
                <div className="opacity-60">
                  {completedGroups.map(({ projectName, projectColor, tasks }) => (
                    <ProjectGroup
                      key={`done-${projectName}`}
                      projectName={projectName}
                      projectColor={projectColor}
                      tasks={tasks}
                      onRefresh={fetchData}
                      isCompleted
                    />
                  ))}
                </div>
              )}
            </section>
          )}
        </>
      )}
    </div>
  )
}
