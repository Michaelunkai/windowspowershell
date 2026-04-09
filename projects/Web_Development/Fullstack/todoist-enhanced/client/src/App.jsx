import { useState, useEffect, useCallback, useRef } from 'react'
import TopBar from './components/TopBar'
import QuickAddModal from './components/QuickAddModal'
import QuickAddTask from './components/QuickAddTask'
import ShortcutsHelpModal from './components/ShortcutsHelpModal'
import WelcomeModal from './components/WelcomeModal'
import OfflineBanner from './components/OfflineBanner'
import PomodoroTimer from './components/PomodoroTimer'
import useKeyboardShortcuts from './hooks/useKeyboardShortcuts'
import { useOfflineDetector } from './hooks/useOfflineDetector'
import { AppProvider, useAppContext } from './context/AppContext'
import { ThemeProvider, useTheme } from './context/ThemeContext'
import './App.css'

const API_BASE = 'http://localhost:3456'
const WORK_SECONDS = 25 * 60

// Inner component — has access to AppContext
function AppInner() {
  const { isOnline } = useOfflineDetector()
  const { isDark: darkMode, toggleTheme } = useTheme()
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [quickAddOpen, setQuickAddOpen] = useState(false)
  const [shortcutsHelpOpen, setShortcutsHelpOpen] = useState(false)
  const [toastMessage, setToastMessage] = useState('')
  const [tasks, setTasks] = useState([])
  const [user, setUser] = useState(
    () => {
      const saved = localStorage.getItem('user_onboarding')
      if (saved === 'completed') return { onboarding_completed: true }
      return { onboarding_completed: false }
    }
  )

  // Keyboard navigation: index of the currently "focused" task row (-1 = none)
  const [focusedTaskIndex, setFocusedTaskIndex] = useState(-1)

  // Undo history: stack of { type, taskId, taskData, previousCompleted } action records
  const undoStackRef = useRef([])

  // Ref forwarded to TopBar so the / shortcut can programmatically focus the search input
  const searchInputRef = useRef(null)

  // Pull focus mode + pomodoro state from context
  const {
    isFocusMode,
    toggleFocusMode,
    timeRemaining,
  } = useAppContext()

  const showToast = (message) => {
    setToastMessage(message)
    setTimeout(() => setToastMessage(''), 2000)
  }

  const fetchTasks = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/api/tasks`)
      if (res.ok) {
        const data = await res.json()
        setTasks(data)
      }
    } catch (err) {
      console.error('Failed to fetch tasks:', err)
    }
  }, [])

  useEffect(() => {
    fetchTasks()
  }, [fetchTasks])

  /**
   * Push an action onto the undo stack so it can be reversed via Ctrl+Z.
   * Supported action types:
   *   { type: 'delete', taskData }  — restore a deleted task
   *   { type: 'complete', taskId, previousCompleted }  — revert a toggle
   */
  const pushUndo = useCallback((action) => {
    undoStackRef.current = [...undoStackRef.current, action]
  }, [])

  /**
   * Ctrl+Z handler — pop the last action from the undo stack and reverse it.
   */
  const handleUndo = useCallback(async () => {
    const stack = undoStackRef.current
    if (stack.length === 0) {
      setToastMessage('Nothing to undo')
      setTimeout(() => setToastMessage(''), 2500)
      return
    }

    const last = stack[stack.length - 1]
    undoStackRef.current = stack.slice(0, -1)

    try {
      if (last.type === 'delete') {
        const res = await fetch(`${API_BASE}/api/tasks`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(last.taskData),
        })
        if (res.ok) {
          fetchTasks()
          setToastMessage('Undo: task restored')
        } else {
          setToastMessage('Undo failed')
        }
      } else if (last.type === 'complete') {
        const res = await fetch(`${API_BASE}/api/tasks/${last.taskId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ completed: last.previousCompleted }),
        })
        if (res.ok) {
          fetchTasks()
          setToastMessage(`Undo: task marked ${last.previousCompleted ? 'complete' : 'incomplete'}`)
        } else {
          setToastMessage('Undo failed')
        }
      } else {
        setToastMessage('Nothing to undo')
      }
    } catch (err) {
      console.error('Undo error:', err)
      setToastMessage('Undo failed')
    }
    setTimeout(() => setToastMessage(''), 2500)
  }, [fetchTasks])

  /** ArrowUp — move keyboard focus to the previous task. */
  const handleArrowUp = useCallback(() => {
    setFocusedTaskIndex((prev) => {
      if (tasks.length === 0) return -1
      return prev <= 0 ? tasks.length - 1 : prev - 1
    })
  }, [tasks.length])

  /** ArrowDown — move keyboard focus to the next task. */
  const handleArrowDown = useCallback(() => {
    setFocusedTaskIndex((prev) => {
      if (tasks.length === 0) return -1
      return prev >= tasks.length - 1 ? 0 : prev + 1
    })
  }, [tasks.length])

  /**
   * Enter — open the task detail/edit modal for the currently focused task,
   * or open Quick Add when nothing is focused.
   */
  const handleEnter = useCallback(() => {
    if (focusedTaskIndex >= 0 && focusedTaskIndex < tasks.length) {
      const task = tasks[focusedTaskIndex]
      setToastMessage(`Opening task: ${task.title}`)
      setTimeout(() => setToastMessage(''), 2500)
      // Dispatch a custom DOM event so child components (TaskList/TaskItem) can
      // open their edit modal without requiring a prop-drilled callback.
      window.dispatchEvent(new CustomEvent('kb:open-task', { detail: { taskId: task.id } }))
    } else {
      setQuickAddOpen(true)
    }
  }, [focusedTaskIndex, tasks])

  /** / key — focus the search input in the TopBar. */
  const handleFocusSearch = useCallback(() => {
    if (searchInputRef.current) {
      searchInputRef.current.focus()
      searchInputRef.current.select()
    }
  }, [])

  const handleQuickAddSubmit = async (taskData) => {
    try {
      const payload = typeof taskData === 'string'
        ? { title: taskData }
        : taskData
      const res = await fetch(`${API_BASE}/api/tasks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      if (res.ok) {
        setQuickAddOpen(false)
        fetchTasks()
        showToast('Task added!')
      } else {
        showToast('Failed to add task')
      }
    } catch (err) {
      console.error('Error adding task:', err)
      showToast('Error adding task')
    }
  }

  // Register all global keyboard shortcuts in App.jsx
  useKeyboardShortcuts({
    onQuickAdd: () => setQuickAddOpen((prev) => !prev),
    onAddTask: () => setQuickAddOpen(true),
    // / key — focus search bar
    onSearch: handleFocusSearch,
    // Ctrl+Z — undo last action
    onUndo: handleUndo,
    // Arrow keys — navigate task list
    onArrowUp: handleArrowUp,
    onArrowDown: handleArrowDown,
    // Enter — open task detail for focused task
    onEnter: handleEnter,
    onShowHelp: () => setShortcutsHelpOpen(true),
    onEscape: () => {
      if (shortcutsHelpOpen) { setShortcutsHelpOpen(false); return }
      if (quickAddOpen) { setQuickAddOpen(false); return }
      // Clear keyboard task focus on Escape
      setFocusedTaskIndex(-1)
    },
    onDeleteTask: () => {
      if (focusedTaskIndex >= 0 && focusedTaskIndex < tasks.length) {
        showToast(`Use right-click to delete: ${tasks[focusedTaskIndex].title}`)
      } else {
        showToast('Select a task first to delete it')
      }
    },
    onToggleFocusMode: toggleFocusMode,
    onNavigate: (view) => showToast(`Navigate to: ${view} (routing coming soon)`),
  })

  const toggleSidebar = () => setSidebarOpen((prev) => !prev)
  const handleSearch = (query) => { setSearchQuery(query) }
  const handleAddTask = () => { setQuickAddOpen(true) }
  const toggleDark = toggleTheme
  const handleSearchNavigate = ({ type, item }) => {
    showToast(`Navigating to ${type}: ${item.title || item.name}`)
  }

  // Timer strip progress (0–1): how far through the 25-min work block
  const timerProgress = Math.max(0, Math.min(1, 1 - timeRemaining / WORK_SECONDS))

  return (
    <div className="flex flex-col min-h-screen bg-white dark:bg-gray-900">
      {/* Pomodoro timer strip — fixed top strip when Focus Mode is active */}
      {isFocusMode && (
        <div
          className="fixed top-0 left-0 right-0 z-[200] h-1 bg-gray-200 dark:bg-gray-700"
          role="progressbar"
          aria-valuenow={Math.round(timerProgress * 100)}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-label="Pomodoro timer progress"
        >
          <div
            className="h-full bg-red-500 transition-all duration-1000 ease-linear"
            style={{ width: `${timerProgress * 100}%` }}
          />
        </div>
      )}

      <OfflineBanner isOnline={isOnline} />
      <TopBar
        className={isFocusMode ? 'hidden' : ''}
        onToggleSidebar={toggleSidebar}
        onSearch={handleSearch}
        onAddTask={handleAddTask}
        onToggleDark={toggleDark}
        onToggleFocusMode={toggleFocusMode}
        onSearchNavigate={handleSearchNavigate}
        isFocusMode={isFocusMode}
        darkMode={darkMode}
        sidebarOpen={sidebarOpen}
        searchInputRef={searchInputRef}
      />
      <div className="flex flex-1 overflow-hidden">
        <aside
          className={`bg-gray-100 dark:bg-gray-800 min-h-full transition-transform duration-300 ease-in-out${
            sidebarOpen && !isFocusMode ? ' w-64 translate-x-0' : ' w-64 -translate-x-full'
          }`}
          style={{ marginLeft: sidebarOpen && !isFocusMode ? 0 : '-16rem' }}
        />
        <main className={`flex-1 p-6 transition-all duration-300${isFocusMode ? ' max-w-2xl mx-auto' : ''}`}>
          {/* App content goes here */}
        </main>
      </div>

      {/* PomodoroTimer overlay — shown when Focus Mode is active */}
      {isFocusMode && (
        <PomodoroTimer onExit={toggleFocusMode} />
      )}

      {/* QuickAddTask modal — triggered by Q key, + key, or the + Add Task button */}
      <QuickAddTask
        isOpen={quickAddOpen}
        onClose={() => setQuickAddOpen(false)}
        onTaskAdded={() => { fetchTasks(); showToast('Task added!') }}
        projects={[]}
      />

      <ShortcutsHelpModal
        isOpen={shortcutsHelpOpen}
        onClose={() => setShortcutsHelpOpen(false)}
      />

      <WelcomeModal
        user={user}
        onComplete={() => {
          localStorage.setItem('user_onboarding', 'completed')
          setUser({ onboarding_completed: true })
        }}
      />

      {/* Focus Mode exit button — shown when NOT using the full PomodoroTimer overlay */}
      {isFocusMode && (
        <button
          onClick={toggleFocusMode}
          className="fixed top-4 right-4 z-50 flex items-center gap-1 text-sm px-3 py-1.5 rounded-full bg-gray-800 text-white opacity-50 hover:opacity-100 transition-opacity duration-200"
          aria-label="Exit Focus Mode"
        >
          Exit Focus <span aria-hidden="true">&#x2715;</span>
        </button>
      )}

      {/* Keyboard navigation indicator — shows which task is currently keyboard-focused */}
      {focusedTaskIndex >= 0 && tasks[focusedTaskIndex] && (
        <div
          className="fixed bottom-16 right-6 z-[90] flex items-center gap-2 bg-blue-600 text-white text-xs font-medium px-3 py-1.5 rounded-full shadow-md pointer-events-none"
          aria-live="polite"
          aria-atomic="true"
        >
          <span aria-hidden="true">&#8593;&#8595;</span>
          Task {focusedTaskIndex + 1}/{tasks.length}: {tasks[focusedTaskIndex].title}
        </div>
      )}

      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-[100] bg-green-600 text-white text-sm font-medium px-4 py-2 rounded-lg shadow-lg">
          {toastMessage}
        </div>
      )}
    </div>
  )
}

function App() {
  return (
    <ThemeProvider>
      <AppProvider>
        <AppInner />
      </AppProvider>
    </ThemeProvider>
  )
}

export default App
