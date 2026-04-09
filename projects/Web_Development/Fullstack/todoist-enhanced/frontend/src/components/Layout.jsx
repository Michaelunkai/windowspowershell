import { useState } from 'react'
import { NavLink } from 'react-router-dom'
import ProjectProgress from './ProjectProgress'
import TaskDetailPanel from './TaskDetailPanel'

const NAV_ITEMS = [
  { to: '/inbox', label: 'Inbox', icon: '📥' },
  { to: '/today', label: 'Today', icon: '☀️' },
  { to: '/upcoming', label: 'Upcoming', icon: '📅' },
  { to: '/priority', label: 'Priority', icon: '🏳️' },
  { to: '/filters', label: 'Filters & Labels', icon: '🏷️' },
]

function Sidebar({ projects = [], labels = [], collapsed, onToggle, onAddProject, onSearch, onQuickAdd, onToggleTheme, dark, onLogout }) {
  const [projectsOpen, setProjectsOpen] = useState(true)
  const [favoritesOpen, setFavoritesOpen] = useState(true)
  const [labelsOpen, setLabelsOpen] = useState(true)
  const favorites = projects.filter(p => p.is_favorite && !p.is_inbox)
  const regularProjects = projects.filter(p => !p.is_inbox && !p.is_favorite)

  return (
    <aside
      className={`flex flex-col bg-gray-900 text-gray-100 h-screen transition-all duration-200 ${
        collapsed ? 'w-12' : 'w-60'
      } shrink-0 overflow-y-auto sidebar-overlay`}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-3 py-3 border-b border-gray-700">
        {!collapsed && <span className="font-bold text-red-400 text-lg">✔ Todoist</span>}
        <button
          onClick={onToggle}
          className="p-1 rounded hover:bg-gray-700 text-gray-400 hover:text-white touch-target"
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? '▶' : '◀'}
        </button>
      </div>

      {!collapsed && (
        <>
          {/* Actions row */}
          <div className="flex items-center gap-1 px-2 py-2 border-b border-gray-700">
            <button
              onClick={onSearch}
              className="flex-1 flex items-center gap-2 px-2 py-1.5 rounded text-sm text-gray-400 hover:bg-gray-700 hover:text-white transition-colors"
              title="Search (/)"
            >
              <span>🔍</span>
              <span>Search</span>
              <span className="ml-auto text-xs text-gray-600">/</span>
            </button>
            <button
              onClick={onQuickAdd}
              className="p-1.5 rounded hover:bg-gray-700 text-gray-400 hover:text-white"
              title="Quick add (Q)"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
              </svg>
            </button>
          </div>

          {/* Main nav */}
          <nav className="mt-2 px-1">
            {NAV_ITEMS.map(item => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `flex items-center gap-2 px-3 py-2 rounded text-sm touch-target ${
                    isActive
                      ? 'bg-red-600 text-white'
                      : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                  }`
                }
              >
                <span>{item.icon}</span>
                <span>{item.label}</span>
              </NavLink>
            ))}
          </nav>

          {/* Favorites */}
          {favorites.length > 0 && (
            <section className="mt-3 px-1">
              <button
                className="w-full flex items-center justify-between px-3 py-1 text-xs font-semibold text-gray-400 uppercase hover:text-white"
                onClick={() => setFavoritesOpen(v => !v)}
              >
                <span>Favorites</span>
                <span>{favoritesOpen ? '▾' : '▸'}</span>
              </button>
              {favoritesOpen && favorites.map(p => (
                <NavLink
                  key={p.id}
                  to={`/project/${p.id}`}
                  className={({ isActive }) =>
                    `flex items-center gap-2 px-3 py-1.5 rounded text-sm ${
                      isActive ? 'bg-gray-600 text-white' : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                    }`
                  }
                >
                  <span style={{ color: p.color || '#6366f1' }}>●</span>
                  <span className="truncate">{p.name}</span>
                </NavLink>
              ))}
            </section>
          )}

          {/* Projects */}
          <section className="mt-3 px-1 flex-1">
            <div className="w-full flex items-center justify-between px-3 py-1">
              <button
                className="flex items-center gap-1 text-xs font-semibold text-gray-400 uppercase hover:text-white"
                onClick={() => setProjectsOpen(v => !v)}
              >
                <span>My Projects</span>
                <span className="ml-1">{projectsOpen ? '▾' : '▸'}</span>
              </button>
              <button
                onClick={onAddProject}
                className="text-gray-500 hover:text-white text-lg leading-none"
                title="Add project"
              >
                +
              </button>
            </div>
            {projectsOpen && regularProjects.map(p => {
              const total = (p.task_count || 0) + (p.completed_count || 0)
              return (
                <NavLink
                  key={p.id}
                  to={`/project/${p.id}`}
                  className={({ isActive }) =>
                    `flex flex-col px-3 py-1.5 rounded text-sm ${
                      isActive ? 'bg-gray-600 text-white' : 'text-gray-300 hover:bg-gray-700 hover:text-white'
                    }`
                  }
                >
                  <div className="flex items-center gap-2">
                    <span style={{ color: p.color || '#6366f1' }}>●</span>
                    <span className="truncate flex-1">{p.name}</span>
                    {p.task_count > 0 && (
                      <span className="ml-auto text-xs text-gray-500">{p.task_count}</span>
                    )}
                  </div>
                  <ProjectProgress completedCount={p.completed_count || 0} totalCount={total} />
                </NavLink>
              )
            })}
          </section>

          {/* Labels */}
          {labels.length > 0 && (
            <section className="mt-3 px-1">
              <button
                className="w-full flex items-center justify-between px-3 py-1 text-xs font-semibold text-gray-400 uppercase hover:text-white"
                onClick={() => setLabelsOpen(v => !v)}
              >
                <span>Labels</span>
                <span>{labelsOpen ? '▾' : '▸'}</span>
              </button>
              {labelsOpen && labels.map(l => (
                <NavLink
                  key={l.id}
                  to={`/filters?label=${l.id}`}
                  className="flex items-center gap-2 px-3 py-1.5 rounded text-sm text-gray-300 hover:bg-gray-700 hover:text-white"
                >
                  <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: l.color || '#6366f1' }} />
                  <span className="truncate">{l.name}</span>
                </NavLink>
              ))}
            </section>
          )}

          {/* Bottom actions: theme + logout */}
          <div className="px-2 py-3 border-t border-gray-700 flex items-center gap-2">
            <button
              onClick={onToggleTheme}
              className="flex-1 flex items-center gap-2 px-2 py-1.5 rounded text-sm text-gray-400 hover:bg-gray-700 hover:text-white transition-colors"
              title="Toggle dark/light mode"
            >
              <span>{dark ? '☀️' : '🌙'}</span>
              <span>{dark ? 'Light mode' : 'Dark mode'}</span>
            </button>
            <button
              onClick={onLogout}
              className="p-1.5 rounded hover:bg-gray-700 text-gray-500 hover:text-white"
              title="Log out"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/>
                <polyline points="16 17 21 12 16 7"/>
                <line x1="21" y1="12" x2="9" y2="12"/>
              </svg>
            </button>
          </div>
        </>
      )}

      {/* Collapsed icons */}
      {collapsed && (
        <div className="flex flex-col items-center gap-1 mt-2 px-1">
          <button onClick={onQuickAdd} className="p-2 rounded hover:bg-gray-700 text-gray-400 hover:text-white" title="Quick add (Q)">+</button>
          <button onClick={onSearch} className="p-2 rounded hover:bg-gray-700 text-gray-400 hover:text-white" title="Search (/)">🔍</button>
          {NAV_ITEMS.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `p-2 rounded text-lg ${isActive ? 'bg-red-600' : 'hover:bg-gray-700'}`
              }
              title={item.label}
            >
              {item.icon}
            </NavLink>
          ))}
        </div>
      )}
    </aside>
  )
}


export default function Layout({ children, projects = [], labels = [], selectedTask, onCloseDetail, onTaskUpdate, onAddProject, onSearch, onQuickAdd, onToggleTheme, dark, onLogout }) {
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <div className="flex h-screen overflow-hidden bg-white dark:bg-gray-900">
      {/* Mobile backdrop */}
      {mobileOpen && (
        <div
          className="sidebar-backdrop md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <div className={`${mobileOpen ? 'sidebar-overlay' : 'hidden md:flex'}`}>
        <Sidebar
          projects={projects}
          labels={labels}
          collapsed={collapsed}
          onToggle={() => setCollapsed(v => !v)}
          onAddProject={onAddProject}
          onSearch={onSearch}
          onQuickAdd={onQuickAdd}
          onToggleTheme={onToggleTheme}
          dark={dark}
          onLogout={onLogout}
        />
      </div>

      {/* Mobile menu button */}
      <button
        className="md:hidden fixed top-3 left-3 z-30 p-2 bg-gray-900 text-white rounded-lg shadow"
        onClick={() => setMobileOpen(v => !v)}
        title="Open menu"
      >
        ☰
      </button>

      <main className="flex-1 overflow-y-auto">
        {children}
      </main>

      {selectedTask && (
        <TaskDetailPanel
          task={selectedTask}
          onClose={onCloseDetail}
          onUpdate={onTaskUpdate}
          projects={projects}
          labels={labels}
        />
      )}
    </div>
  )
}
