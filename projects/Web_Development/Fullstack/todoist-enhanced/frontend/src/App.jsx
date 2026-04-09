import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useState, useEffect, createContext, useContext, useCallback } from 'react'
import Layout from './components/Layout'
import api, { getProjects, getLabels } from './api'
import { ThemeProvider, useTheme } from './ThemeContext'
import GlobalSearch from './components/GlobalSearch'
import QuickAddTask from './components/QuickAddTask'
import ProjectDialog from './components/ProjectDialog'
import InboxView from './pages/InboxView'
import TodayView from './pages/TodayView'
import UpcomingView from './pages/UpcomingView'
import FiltersView from './pages/FiltersView'
import ProjectView from './pages/ProjectView'
import PriorityView from './components/PriorityView'

// Auth Context
export const AuthContext = createContext(null)
export function useAuth() { return useContext(AuthContext) }

function NotFound() {
  return <div className="p-6"><h1 className="text-2xl font-bold">404 — Not Found</h1></div>
}

// Login page
function Login({ onLogin }) {
  const [email, setEmail] = useState('demo@example.com')
  const [password, setPassword] = useState('password123')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      const res = await api.post('/api/auth/login', { email, password })
      const token = res.data.token
      localStorage.setItem('token', token)
      onLogin(res.data.user, token)
    } catch (err) {
      setError(err.response?.data?.error || 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-50 dark:bg-gray-900">
      <form onSubmit={handleSubmit} className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-8 w-80 space-y-4">
        <h1 className="text-2xl font-bold text-center text-red-500">Todoist Enhanced</h1>
        {error && <div className="text-red-500 text-sm text-center">{error}</div>}
        <div>
          <label className="block text-sm font-medium mb-1">Email</label>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            className="w-full border border-gray-300 dark:border-gray-600 rounded px-3 py-2 text-sm bg-white dark:bg-gray-700"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-1">Password</label>
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            className="w-full border border-gray-300 dark:border-gray-600 rounded px-3 py-2 text-sm bg-white dark:bg-gray-700"
            required
          />
        </div>
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-red-500 hover:bg-red-600 text-white rounded py-2 font-medium disabled:opacity-50"
        >
          {loading ? 'Logging in...' : 'Log In'}
        </button>
      </form>
    </div>
  )
}

function AppShell({ user, onLogout }) {
  const [projects, setProjects] = useState([])
  const [labels, setLabels] = useState([])
  const [selectedTask, setSelectedTask] = useState(null)
  const [showSearch, setShowSearch] = useState(false)
  const [showQuickAdd, setShowQuickAdd] = useState(false)
  const [showProjectDialog, setShowProjectDialog] = useState(false)
  const { dark, toggle: toggleTheme } = useTheme()

  // Undo stack
  const [undoStack, setUndoStack] = useState([])

  const loadData = useCallback(() => {
    getProjects().then(r => setProjects(r.data.projects || [])).catch(() => {})
    getLabels().then(r => setLabels(r.data.labels || [])).catch(() => {})
  }, [])

  useEffect(() => { loadData() }, [loadData])

  // Global keyboard shortcuts
  useEffect(() => {
    function handleKey(e) {
      const tag = document.activeElement?.tagName?.toLowerCase()
      const isInput = tag === 'input' || tag === 'textarea' || tag === 'select' ||
        document.activeElement?.isContentEditable

      // Q = quick add (not in input)
      if (!isInput && e.key === 'q' && !e.ctrlKey && !e.metaKey) {
        e.preventDefault()
        setShowQuickAdd(true)
        return
      }
      // / = search (not in input)
      if (!isInput && e.key === '/' && !e.ctrlKey && !e.metaKey) {
        e.preventDefault()
        setShowSearch(true)
        return
      }
      // Ctrl+Z = undo
      if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
        e.preventDefault()
        handleUndo()
        return
      }
      // Escape = close modals
      if (e.key === 'Escape') {
        if (showSearch) setShowSearch(false)
        if (showQuickAdd) setShowQuickAdd(false)
        if (showProjectDialog) setShowProjectDialog(false)
        if (selectedTask) setSelectedTask(null)
      }
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [showSearch, showQuickAdd, showProjectDialog, selectedTask, undoStack])

  function handleUndo() {
    if (undoStack.length === 0) return
    const last = undoStack[undoStack.length - 1]
    setUndoStack(prev => prev.slice(0, -1))
    // Simple: just reload data on undo
    loadData()
  }

  function handleProjectCreated(project) {
    setProjects(prev => [...prev, project])
  }

  function handleTaskCreated() {
    // Reload projects to refresh task counts
    getProjects().then(r => setProjects(r.data.projects || [])).catch(() => {})
  }

  const viewProps = { projects, labels, onTaskClick: setSelectedTask }

  return (
    <BrowserRouter>
      <Layout
        projects={projects}
        labels={labels}
        selectedTask={selectedTask}
        onCloseDetail={() => setSelectedTask(null)}
        onTaskUpdate={task => { if (selectedTask?.id === task.id) setSelectedTask(task) }}
        onAddProject={() => setShowProjectDialog(true)}
        onSearch={() => setShowSearch(true)}
        onQuickAdd={() => setShowQuickAdd(true)}
        onToggleTheme={toggleTheme}
        dark={dark}
        onLogout={onLogout}
      >
        <Routes>
          <Route path="/" element={<Navigate to="/inbox" replace />} />
          <Route path="/inbox" element={<InboxView {...viewProps} />} />
          <Route path="/today" element={<TodayView {...viewProps} />} />
          <Route path="/upcoming" element={<UpcomingView {...viewProps} />} />
          <Route path="/priority" element={<PriorityView onSelectTask={setSelectedTask} onTaskUpdate={() => {}} />} />
          <Route path="/filters" element={<FiltersView labels={labels} onTaskClick={setSelectedTask} />} />
          <Route path="/project/:id" element={<ProjectView {...viewProps} />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Layout>

      {/* Global search overlay */}
      {showSearch && <GlobalSearch onClose={() => setShowSearch(false)} />}

      {/* Quick add modal */}
      <QuickAddTask
        open={showQuickAdd}
        onClose={() => setShowQuickAdd(false)}
        onCreated={handleTaskCreated}
        projects={projects}
        labels={labels}
      />

      {/* Project creation dialog */}
      <ProjectDialog
        open={showProjectDialog}
        onClose={() => setShowProjectDialog(false)}
        onCreated={handleProjectCreated}
      />
    </BrowserRouter>
  )
}

export default function App() {
  const [user, setUser] = useState(() => {
    const token = localStorage.getItem('token')
    return token ? { token } : null
  })

  function handleLogin(userData, token) {
    setUser({ ...userData, token })
  }

  function handleLogout() {
    localStorage.removeItem('token')
    setUser(null)
  }

  return (
    <ThemeProvider>
      {!user ? (
        <Login onLogin={handleLogin} />
      ) : (
        <AuthContext.Provider value={{ user, logout: handleLogout }}>
          <AppShell user={user} onLogout={handleLogout} />
        </AuthContext.Provider>
      )}
    </ThemeProvider>
  )
}
