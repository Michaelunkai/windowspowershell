/**
 * LabelSelector — checkbox list of all labels, multi-select, color coded.
 * Props:
 *   labels    {array}   all available labels [{id, name, color}]
 *   selected  {array}   array of selected label ids
 *   onChange  {fn}      (selectedIds: number[]) => void
 */
export default function LabelSelector({ labels = [], selected = [], onChange }) {
  function toggle(id) {
    if (selected.includes(id)) {
      onChange && onChange(selected.filter(x => x !== id))
    } else {
      onChange && onChange([...selected, id])
    }
  }

  if (labels.length === 0) {
    return (
      <div className="text-sm text-gray-400 italic py-2">No labels available</div>
    )
  }

  return (
    <div className="flex flex-col gap-1 max-h-48 overflow-y-auto" role="group" aria-label="Label selector">
      {labels.map(label => {
        const isSelected = selected.includes(label.id)
        return (
          <label
            key={label.id}
            className={`flex items-center gap-2 px-2 py-1.5 rounded-lg cursor-pointer transition-colors
              ${isSelected ? 'bg-indigo-50 dark:bg-indigo-900/30' : 'hover:bg-gray-100 dark:hover:bg-gray-800'}`}
          >
            <input
              type="checkbox"
              checked={isSelected}
              onChange={() => toggle(label.id)}
              className="w-3.5 h-3.5 rounded accent-indigo-500"
            />
            <span
              className="w-2.5 h-2.5 rounded-full shrink-0"
              style={{ backgroundColor: label.color || '#6366f1' }}
            />
            <span className="text-sm text-gray-700 dark:text-gray-300">{label.name}</span>
          </label>
        )
      })}
    </div>
  )
}
