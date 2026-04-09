import axios from 'axios'

const BASE = import.meta.env.VITE_API_URL || 'http://localhost:3456'

const api = axios.create({
  baseURL: BASE,
  withCredentials: true,
})

// Attach token from localStorage if present
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

export default api

// Auth
export const login = (email, password) =>
  api.post('/api/auth/login', { email, password })
export const register = (email, password, name) =>
  api.post('/api/auth/register', { email, password, name })
export const logout = () => api.post('/api/auth/logout')

// Projects
export const getProjects = () => api.get('/api/projects')
export const createProject = data => api.post('/api/projects', data)
export const updateProject = (id, data) => api.put(`/api/projects/${id}`, data)
export const deleteProject = id => api.delete(`/api/projects/${id}`)

// Tasks
export const getTasks = params => api.get('/api/tasks', { params })
export const createTask = data => api.post('/api/tasks', data)
export const updateTask = (id, data) => api.put(`/api/tasks/${id}`, data)
export const deleteTask = id => api.delete(`/api/tasks/${id}`)
export const completeTask = id => api.post(`/api/tasks/${id}/complete`)
export const uncompleteTask = id => api.post(`/api/tasks/${id}/uncomplete`)

// Views
export const getInbox = () => api.get('/api/views/inbox')
export const getToday = () => api.get('/api/views/today')
export const getUpcoming = () => api.get('/api/views/upcoming')

// Labels
export const getLabels = () => api.get('/api/labels')
export const createLabel = data => api.post('/api/labels', data)
export const updateLabel = (id, data) => api.put(`/api/labels/${id}`, data)
export const deleteLabel = id => api.delete(`/api/labels/${id}`)

// Sections
export const getSections = projectId => api.get(`/api/projects/${projectId}/sections`)
export const createSection = (projectId, data) => api.post(`/api/projects/${projectId}/sections`, data)
export const updateSection = (id, data) => api.put(`/api/sections/${id}`, data)
export const deleteSection = id => api.delete(`/api/sections/${id}`)

// Comments
export const getComments = taskId => api.get(`/api/tasks/${taskId}/comments`)
export const addComment = (taskId, content) => api.post(`/api/tasks/${taskId}/comments`, { content })
export const deleteComment = (taskId, commentId) => api.delete(`/api/tasks/${taskId}/comments/${commentId}`)

// Filters
export const getFilters = () => api.get('/api/filters')
export const createFilter = data => api.post('/api/filters', data)
export const updateFilter = (id, data) => api.put(`/api/filters/${id}`, data)
export const deleteFilter = id => api.delete(`/api/filters/${id}`)

// Search
export const search = q => api.get('/api/search', { params: { q } })

// Reorder tasks (if endpoint exists)
export const reorderTasks = (projectId, taskIds) =>
  api.post(`/api/projects/${projectId}/tasks/reorder`, { task_ids: taskIds }).catch(() => {})
