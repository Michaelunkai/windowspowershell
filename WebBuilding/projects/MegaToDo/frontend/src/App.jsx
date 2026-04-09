import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import EmptyState from './components/EmptyState'

function Inbox() {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-bold mb-6">Inbox</h1>
      <EmptyState type="inbox" />
    </main>
  )
}

function Today() {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-bold mb-6">Today</h1>
      <EmptyState type="today" />
    </main>
  )
}

function Upcoming() {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-bold mb-6">Upcoming</h1>
      <EmptyState type="upcoming" />
    </main>
  )
}

function Projects() {
  return (
    <main className="p-6">
      <h1 className="text-2xl font-bold mb-6">Projects</h1>
      <EmptyState type="projects" />
    </main>
  )
}

function NotFound() {
  return <main className="p-6"><h1 className="text-2xl font-bold">404 - Page Not Found</h1></main>
}

export default function App() {
  return (
    <BrowserRouter>
      <div className="flex flex-col min-h-screen bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
        <Routes>
          <Route path="/" element={<Navigate to="/inbox" replace />} />
          <Route path="/inbox" element={<Inbox />} />
          <Route path="/today" element={<Today />} />
          <Route path="/upcoming" element={<Upcoming />} />
          <Route path="/projects" element={<Projects />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </div>
    </BrowserRouter>
  )
}
