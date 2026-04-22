// app/frontend/src/App.jsx
import { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'

const API = import.meta.env.VITE_API_URL || 'http://localhost:5000'

function App() {
  const [tasks, setTasks]   = useState([])
  const [title, setTitle]   = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError]   = useState(null)

  // Fetch all tasks on mount
  useEffect(() => {
    fetchTasks()
  }, [])

  const fetchTasks = async () => {
    try {
      setLoading(true)
      const res = await axios.get(`${API}/api/tasks`)
      setTasks(res.data)
      setError(null)
    } catch (err) {
      setError('Failed to connect to the backend. Is it running?')
    } finally {
      setLoading(false)
    }
  }

  const addTask = async (e) => {
    e.preventDefault()
    if (!title.trim()) return

    try {
      const res = await axios.post(`${API}/api/tasks`, { title })
      setTasks([res.data, ...tasks])
      setTitle('')
    } catch (err) {
      setError('Failed to add task')
    }
  }

  const toggleTask = async (id) => {
    try {
      const res = await axios.patch(`${API}/api/tasks/${id}`)
      setTasks(tasks.map(t => t.id === id ? res.data : t))
    } catch (err) {
      setError('Failed to update task')
    }
  }

  const deleteTask = async (id) => {
    try {
      await axios.delete(`${API}/api/tasks/${id}`)
      setTasks(tasks.filter(t => t.id !== id))
    } catch (err) {
      setError('Failed to delete task')
    }
  }

  return (
    <div className="container">
      <h1>Task Manager</h1>
      <p className="subtitle">Running on AWS EKS</p>

      {/* Add task form */}
      <form onSubmit={addTask} className="task-form">
        <input
          type="text"
          placeholder="Enter a new task..."
          value={title}
          onChange={e => setTitle(e.target.value)}
          className="task-input"
        />
        <button type="submit" className="btn-add">Add Task</button>
      </form>

      {/* Error banner */}
      {error && (
        <div className="error-banner">
          {error}
          <button onClick={() => setError(null)}>✕</button>
        </div>
      )}

      {/* Task list */}
      {loading ? (
        <p className="loading">Loading tasks...</p>
      ) : tasks.length === 0 ? (
        <p className="empty">No tasks yet. Add one above.</p>
      ) : (
        <ul className="task-list">
          {tasks.map(task => (
            <li key={task.id} className={`task-item ${task.completed ? 'completed' : ''}`}>
              <input
                type="checkbox"
                checked={task.completed}
                onChange={() => toggleTask(task.id)}
              />
              <span className="task-title">{task.title}</span>
              <span className="task-date">
                {new Date(task.created_at).toLocaleDateString()}
              </span>
              <button
                onClick={() => deleteTask(task.id)}
                className="btn-delete"
              >
                Delete
              </button>
            </li>
          ))}
        </ul>
      )}

      <p className="task-count">
        {tasks.filter(t => !t.completed).length} remaining /
        {tasks.length} total
      </p>
    </div>
  )
}

export default App
