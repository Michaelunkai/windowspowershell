# MegaToDo Architecture

## Overview
MegaToDo (formerly todoist-enhanced) is a fullstack React+Node.js+SQLite todo app.

## Tech Stack
- **Frontend:** React 18 + Vite, React Router, Tailwind CSS
- **Backend:** Node.js + Express (server.js, port 3456)
- **Database:** SQLite (db/todoist.db)
- **Auth:** JWT-based (middleware/auth.js)
- **Deploy:** Netlify (netlify.toml)

## Directory Structure
```
F:/Downloads/MegaToDo/
  server.js              # Express app entry point
  db/
    init.js              # DB init, schema load, migrations
    schema.sql           # Base schema (16 tables)
    todoist.db           # SQLite database file
  migrations.sql         # Extended migrations
  routes/
    auth.js              # POST /api/auth/register, /login, /logout
    projects.js          # CRUD /api/projects
    tasks.js             # CRUD /api/tasks + subtaskRouter
    labels.js            # /api/labels + taskLabelRouter
    sections.js          # /api/sections + projectSectionsRouter
    comments.js          # /api/tasks/:id/comments + /api/comments
    karma.js             # /api/karma
    views.js             # /api/views
    filters.js           # /api/filters
    search.js            # /api/search
  middleware/
    auth.js              # JWT authMiddleware
  utils/
    karma.js             # Karma utility
  frontend/src/
    App.jsx              # React Router (PLACEHOLDER - minimal implementation)
    main.jsx             # Entry point
    components/
      DueDatePicker.jsx
      EmptyState.jsx
    index.css
  public/                # Static assets
```

## Database Tables (16)
1. users - id, email, password_hash, display_name, onboarding_completed
2. projects - id, user_id, name, color, sort_order, is_archived, is_favorite
3. sections - id, project_id, user_id, name, sort_order, is_collapsed
4. tasks - id, project_id, user_id, section_id, title, description, priority, due_date, recurring, parent_id, pomodoros_done
5. subtasks - id, task_id, user_id, title, is_completed
6. labels - id, user_id, name, color, sort_order, is_favorite
7. task_labels - task_id, label_id
8. comments - id, task_id, user_id, content, attachment_url
9. filters - id, user_id, name, color, query, sort_order, is_favorite
10. recurring_tasks - id, user_id, ...
11. time_entries - id, task_id, user_id, ...
12. task_dependencies - task_id, depends_on
13. activity_log - id, user_id, action, entity_type, entity_id
14. webhooks - id, user_id, url, events
15. task_templates - id, user_id, name, template_data
16. karma_log - id, user_id, points, reason
17. user_settings - id, user_id, key, value (via migration)

## Backend API Routes
- POST /api/auth/register, /api/auth/login, /api/auth/logout
- GET/POST/PUT/DELETE /api/projects
- GET/POST/PUT/DELETE /api/tasks
- GET/POST /api/tasks/:id/comments
- GET/POST/PUT/DELETE /api/labels
- GET/POST/PUT/DELETE /api/sections
- GET/POST/PUT/DELETE /api/filters
- GET /api/search?q=
- GET/POST /api/karma
- GET/POST/PUT/DELETE /api/views

## Frontend Status
- App.jsx: PLACEHOLDER only (Inbox/Today/Upcoming/Projects are stub components)
- NO login/signup pages implemented in frontend yet
- NO project/task display components
- Only 2 real components: DueDatePicker.jsx, EmptyState.jsx
- NEEDS: Login page, Signup page, main task views, project sidebar, task forms

## Key Issues to Address
1. Frontend is nearly empty - needs full implementation
2. Admin user (michaelovsky5@gmail.com / Aa1111111!) needs to be seeded
3. Todoist API sync not implemented
4. App name still shows "Todoist Enhanced" in some places
