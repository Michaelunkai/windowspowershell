import { useState, useEffect, useRef, useCallback } from 'react'
import { search } from '../api'
import { useNavigate } from 'react-router-dom'

export default function GlobalSearch({ onClose }) {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState({ tasks: [], projects: [], labels: [] })
  const [loading, setLoading] = useState(false)
  const [selected, setSelected] = useState(0)
  const inputRef = useRef(null)
  const navigate = useNavigate()

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  useEffect(() => {
    if (!query.trim()) {
      setResults({ tasks: [], projects: [], labels: [] })
      return
    }
    const timer = setTimeout(async () => {
      setLoading(true)
      try {
        const res = await search(query.trim())
        setResults(res.data || { tasks: [], projects: [], labels: [] })
      } catch {
        setResults({ tasks: [], projects: [], labels: [] })
      } finally {
        setLoading(false)
      }
    }, 200)
    return () => clearTimeout(timer)
  }, [query])

  const allItems = [
    ...(results.tasks || []).map(t => ({ type: 'task', label: t.title, sub: t.project_name, id: t.id, projectId: t.project_id })),
    ...(results.projects || []).map(p => ({ type: 'project', label: p.name, sub: 'Project', id: p.id })),
    ...(results.labels || []).map(l => ({ type: 'label', label: l.name, sub: 'Label', id: l.id })),
  ]

  const handleSelect = useCallback((item) => {
    if (!item) return
    if (item.type === 'project') navigate(`/project/${item.id}`)
    else if (item.type === 'task' && item.projectId) navigate(`/project/${item.projectId}`)
    onClose()
  }, [navigate, onClose])

  function handleKeyDown(e) {
    if (e.key === 'Escape') { onClose(); return }
    if (e.key === 'ArrowDown') { e.preventDefault(); setSelected(s => Math.min(s + 1, allItems.length - 1)) }
    if (e.key === 'ArrowUp') { e.preventDefault(); setSelected(s => Math.max(s - 1, 0)) }
    if (e.key === 'Enter') { handleSelect(allItems[selected]) }
  }

  const typeIcon = { task: '✔', project: '●', label: '🏷' }

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center pt-20 bg-black/40"
      onClick={onClose}
    >
      <div
        className="search-overlay bg-white dark:bg-gray-800 rounded-xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden"
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center gap-3 px-4 py-3 border-b border-gray-200 dark:border-gray-700">
          <span className="text-gray-400 text-lg">🔍</span>
          <input
            ref={inputRef}
            value={query}
            onChange={e => { setQuery(e.target.value); setSelected(0) }}
            onKeyDown={handleKeyDown}
            placeholder="Search tasks, projects, labels..."
            className="flex-1 bg-transparent text-sm outline-none text-gray-800 dark:text-gray-100 placeholder-gray-400"
          />
          {loading && <span className="text-xs text-gray-400 animate-pulse">Searching...</span>}
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-lg ml-1">×</button>
        </div>

        {allItems.length > 0 && (
          <ul className="max-h-80 overflow-y-auto py-2">
            {allItems.map((item, i) => (
              <li
                key={`${item.type}-${item.id}`}
                className={`flex items-center gap-3 px-4 py-2.5 cursor-pointer text-sm transition-colors
                  ${i === selected ? 'bg-red-50 dark:bg-red-900/20' : 'hover:bg-gray-50 dark:hover:bg-gray-700/50'}`}
                onClick={() => handleSelect(item)}
                onMouseEnter={() => setSelected(i)}
              >
                <span className="text-gray-400 w-4 text-center">{typeIcon[item.type]}</span>
                <div className="flex-1 min-w-0">
                  <span className="text-gray-800 dark:text-gray-100 truncate block">{item.label}</span>
                  {item.sub && <span className="text-xs text-gray-400 truncate block">{item.sub}</span>}
                </div>
                <span className="text-xs text-gray-300 dark:text-gray-600 capitalize">{item.type}</span>
              </li>
            ))}
          </ul>
        )}

        {query && !loading && allItems.length === 0 && (
          <div className="px-4 py-8 text-center text-sm text-gray-400">
            No results for "{query}"
          </div>
        )}

        {!query && (
          <div className="px-4 py-4 text-xs text-gray-400 text-center">
            Type to search across tasks, projects and labels
          </div>
        )}
      </div>
    </div>
  )
}
