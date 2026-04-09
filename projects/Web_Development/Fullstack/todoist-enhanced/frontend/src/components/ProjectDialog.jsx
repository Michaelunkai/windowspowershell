import { useState, useEffect, useRef } from 'react'
import { createProject } from '../api'

const TODOIST_COLORS = [
  { name: 'Berry Red', hex: '#B8255F' },
  { name: 'Red', hex: '#DB4035' },
  { name: 'Orange', hex: '#FF9933' },
  { name: 'Yellow', hex: '#FAD000' },
  { name: 'Olive Green', hex: '#AFB83B' },
  { name: 'Lime Green', hex: '#7ECC49' },
  { name: 'Green', hex: '#299438' },
  { name: 'Mint Green', hex: '#6ACCBC' },
  { name: 'Teal', hex: '#158FAD' },
  { name: 'Sky Blue', hex: '#14AAF5' },
  { name: 'Light Blue', hex: '#96C3EB' },
  { name: 'Blue', hex: '#4073FF' },
  { name: 'Grape', hex: '#884DFF' },
  { name: 'Violet', hex: '#AF38EB' },
  { name: 'Lavender', hex: '#EB96EB' },
  { name: 'Magenta', hex: '#E05194' },
  { name: 'Salmon', hex: '#FF8D85' },
  { name: 'Charcoal', hex: '#808080' },
  { name: 'Grey', hex: '#B8B8B8' },
  { name: 'Taupe', hex: '#CCAC93' },
  { name: 'White', hex: '#FFFFFF' },
]

export default function ProjectDialog({ open, onClose, onCreated }) {
  const [name, setName] = useState('')
  const [color, setColor] = useState('#6366f1')
  const [isFavorite, setIsFavorite] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const inputRef = useRef(null)

  useEffect(() => {
    if (open) {
      setName('')
      setColor('#6366f1')
      setIsFavorite(false)
      setError('')
      setTimeout(() => inputRef.current?.focus(), 50)
    }
  }, [open])

  useEffect(() => {
    function handleKey(e) {
      if (e.key === 'Escape') onClose && onClose()
    }
    if (open) document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [open, onClose])

  async function handleSubmit(e) {
    e.preventDefault()
    if (!name.trim()) return
    setLoading(true)
    setError('')
    try {
      const res = await createProject({ name: name.trim(), color, is_favorite: isFavorite })
      onCreated && onCreated(res.data.project || res.data)
      onClose && onClose()
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to create project')
    } finally {
      setLoading(false)
    }
  }

  if (!open) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm"
      onClick={e => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-2xl w-full max-w-md mx-4">
        <div className="p-5 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Add project</h2>
        </div>
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Name</label>
            <input
              ref={inputRef}
              type="text"
              value={name}
              onChange={e => setName(e.target.value)}
              placeholder="Project name"
              className="w-full border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-red-500"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Color</label>
            <div className="flex flex-wrap gap-2">
              {TODOIST_COLORS.map(c => (
                <button
                  key={c.hex}
                  type="button"
                  title={c.name}
                  onClick={() => setColor(c.hex)}
                  className={`w-6 h-6 rounded-full border-2 transition-transform hover:scale-110 ${
                    color === c.hex ? 'border-gray-800 dark:border-white scale-110' : 'border-transparent'
                  }`}
                  style={{ backgroundColor: c.hex }}
                />
              ))}
            </div>
          </div>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={isFavorite}
              onChange={e => setIsFavorite(e.target.checked)}
              className="w-4 h-4 accent-red-500"
            />
            <span className="text-sm text-gray-700 dark:text-gray-300">Add to favorites</span>
          </label>

          {error && <div className="text-red-500 text-sm">{error}</div>}

          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!name.trim() || loading}
              className="px-4 py-2 text-sm bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium disabled:opacity-50"
            >
              {loading ? 'Creating...' : 'Add project'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
