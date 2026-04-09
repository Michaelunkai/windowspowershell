/**
 * PrioritySelector — P1/P2/P3/P4 radio buttons with Todoist colors.
 * Props:
 *   value    {number}  1-4 (1 = urgent/red, 4 = none/grey)
 *   onChange {fn}      (priority: number) => void
 */
const PRIORITIES = [
  { value: 1, label: 'P1', color: '#DB4035', title: 'Priority 1 (Urgent)' },
  { value: 2, label: 'P2', color: '#FF9933', title: 'Priority 2 (High)' },
  { value: 3, label: 'P3', color: '#4073FF', title: 'Priority 3 (Medium)' },
  { value: 4, label: 'P4', color: '#808080', title: 'Priority 4 (None)' },
]

export { PRIORITIES }

export default function PrioritySelector({ value = 4, onChange }) {
  return (
    <div className="flex gap-2" role="radiogroup" aria-label="Task priority">
      {PRIORITIES.map(p => (
        <button
          key={p.value}
          type="button"
          role="radio"
          aria-checked={value === p.value}
          aria-label={p.title}
          title={p.title}
          onClick={() => onChange && onChange(p.value)}
          className={`flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm font-medium transition-all
            focus:outline-none focus:ring-2 focus:ring-offset-1`}
          style={{
            borderColor: p.color,
            backgroundColor: value === p.value ? p.color : 'transparent',
            color: value === p.value ? '#fff' : p.color,
          }}
        >
          <span
            className="w-2.5 h-2.5 rounded-full border-2 inline-block"
            style={{
              borderColor: value === p.value ? '#fff' : p.color,
              backgroundColor: value === p.value ? '#fff' : 'transparent',
            }}
          />
          {p.label}
        </button>
      ))}
    </div>
  )
}
