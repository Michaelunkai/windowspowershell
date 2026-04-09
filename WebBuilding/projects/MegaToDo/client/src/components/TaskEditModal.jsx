import TaskDetailPanel from './TaskDetailPanel'

/**
 * TaskEditModal — thin wrapper around TaskDetailPanel for use from TaskList.
 *
 * Props:
 *   task    {object}  task to edit
 *   onClose {fn}      called to dismiss
 *   onSave  {fn}      called after a successful save
 */
export default function TaskEditModal({ task, onClose, onSave }) {
  return (
    <TaskDetailPanel
      task={task}
      onClose={onClose}
      onUpdated={() => {
        onSave && onSave()
      }}
      onDeleted={() => {
        onSave && onSave()
        onClose()
      }}
    />
  )
}
