/**
 * TaskList — renders a sortable list of tasks with DnD reordering,
 * sub-tasks (nested indentation), recurring task badge, and completion animations.
 */
import { useState, useCallback } from 'react'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core'
import {
  SortableContext,
  sortableKeyboardCoordinates,
  verticalListSortingStrategy,
  useSortable,
  arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import TaskItem from './TaskItem'

// Recurring badge
function RecurringBadge({ recurrence }) {
  if (!recurrence) return null
  const labels = { daily: '↻ Daily', weekly: '↻ Weekly', monthly: '↻ Monthly', custom: '↻ Custom' }
  return (
    <span className="text-xs text-blue-500 font-medium ml-1">{labels[recurrence] || `↻ ${recurrence}`}</span>
  )
}

// Sub-task count badge
function SubTaskBadge({ count }) {
  if (!count) return null
  return (
    <span className="text-xs bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 px-1.5 py-0.5 rounded ml-1">
      {count} subtask{count !== 1 ? 's' : ''}
    </span>
  )
}

// Sortable wrapper for each task
function SortableTaskRow({ task, depth = 0, onUpdate, onComplete, onClick, subTasks, allTasks, onUpdateAll }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: task.id })
  const [expanded, setExpanded] = useState(true)
  const [completing, setCompleting] = useState(false)

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  }

  function handleComplete(taskId) {
    setCompleting(true)
    setTimeout(() => {
      setCompleting(false)
      onComplete && onComplete(taskId)
    }, 400)
  }

  const childTasks = subTasks.filter(s => s.parent_id === task.id)
  const hasChildren = childTasks.length > 0

  return (
    <div ref={setNodeRef} style={style}>
      <div
        className={`flex items-start ${completing ? 'task-completing' : ''}`}
        style={{ paddingLeft: depth * 20 }}
      >
        {/* Drag handle */}
        <button
          {...attributes}
          {...listeners}
          className="opacity-0 group-hover:opacity-100 cursor-grab active:cursor-grabbing text-gray-300 hover:text-gray-500 mr-1 mt-2 shrink-0 px-0.5"
          style={{ touchAction: 'none' }}
          title="Drag to reorder"
          tabIndex={-1}
        >
          ⠿
        </button>

        {/* Expand/collapse for parent tasks */}
        {hasChildren && (
          <button
            onClick={() => setExpanded(v => !v)}
            className="text-gray-400 hover:text-gray-600 text-xs mt-2.5 mr-1 shrink-0 w-4"
            title={expanded ? 'Collapse' : 'Expand'}
          >
            {expanded ? '▾' : '▸'}
          </button>
        )}
        {!hasChildren && depth === 0 && <span className="w-5 shrink-0" />}

        <div className="flex-1 min-w-0 group">
          <div className="flex items-center">
            <div className="flex-1 min-w-0">
              <TaskItem
                task={task}
                onUpdate={onUpdate}
                onComplete={handleComplete}
                onClick={onClick}
              />
            </div>
            <RecurringBadge recurrence={task.recurrence} />
            <SubTaskBadge count={childTasks.length} />
          </div>
        </div>
      </div>

      {/* Sub-tasks */}
      {hasChildren && expanded && childTasks.map(child => (
        <SortableTaskRow
          key={child.id}
          task={child}
          depth={depth + 1}
          onUpdate={onUpdate}
          onComplete={onComplete}
          onClick={onClick}
          subTasks={allTasks.filter(t => t.parent_id === child.id)}
          allTasks={allTasks}
          onUpdateAll={onUpdateAll}
        />
      ))}
    </div>
  )
}

export default function TaskList({ tasks = [], onUpdate, onComplete, onClick, onReorder }) {
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  )

  // Separate top-level tasks from sub-tasks
  const topLevel = tasks.filter(t => !t.parent_id)
  const subTasks = tasks.filter(t => t.parent_id)

  function handleDragEnd(event) {
    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIdx = topLevel.findIndex(t => t.id === active.id)
    const newIdx = topLevel.findIndex(t => t.id === over.id)
    if (oldIdx === -1 || newIdx === -1) return
    const reordered = arrayMove(topLevel, oldIdx, newIdx)
    onReorder && onReorder(reordered)
  }

  if (tasks.length === 0) return null

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
      <SortableContext items={topLevel.map(t => t.id)} strategy={verticalListSortingStrategy}>
        <div className="space-y-0.5">
          {topLevel.map(task => (
            <SortableTaskRow
              key={task.id}
              task={task}
              onUpdate={onUpdate}
              onComplete={onComplete}
              onClick={onClick}
              subTasks={subTasks.filter(s => s.parent_id === task.id)}
              allTasks={subTasks}
              onUpdateAll={onUpdate}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  )
}
