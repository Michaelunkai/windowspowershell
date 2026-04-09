const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { run, get, all } = require('../db/init');
const { authMiddleware } = require('../middleware/auth');
const { TodoistClient } = require('../utils/todoist-api');

const router = express.Router();
router.use(authMiddleware);

// Map Todoist priority (1=lowest, 4=highest) to our priority (1=highest, 4=lowest)
function mapPriority(todoistPriority) {
  const map = { 1: 4, 2: 3, 3: 2, 4: 1 };
  return map[todoistPriority] || 4;
}

// Todoist color name -> hex
const TODOIST_COLORS = {
  berry_red: '#b8255f', red: '#db4035', orange: '#ff9933', yellow: '#fad000',
  olive_green: '#afb83b', lime_green: '#7ecc49', green: '#299438', mint_green: '#6accbc',
  teal: '#158fad', sky_blue: '#14aaf5', light_blue: '#96c3eb', blue: '#4073ff',
  grape: '#884dff', violet: '#af38eb', lavender: '#eb96eb', magenta: '#e05194',
  salmon: '#ff8d85', charcoal: '#808080', grey: '#b8b8b8', taupe: '#ccac93'
};

// Parse Todoist recurring string (e.g. "every day", "every week", "every mon,wed,fri")
// into { type, interval, weekdays } for the recurring_tasks table
function parseRecurringPattern(recurStr) {
  if (!recurStr) return { type: 'daily', interval: 1, weekdays: null };
  const s = recurStr.toLowerCase().trim();

  // Match "every N days/weeks/months/years"
  const intervalMatch = s.match(/every\s+(\d+)\s+(day|week|month|year)s?/);
  if (intervalMatch) {
    return { type: intervalMatch[2] + 'ly', interval: parseInt(intervalMatch[1], 10), weekdays: null };
  }

  // Match weekday lists: "every mon,wed,fri" or "every monday, wednesday"
  const dayAbbrevs = { sun: 0, mon: 1, tue: 2, wed: 3, thu: 4, fri: 5, sat: 6,
    sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 };
  const weekdayMatch = s.match(/every\s+(.+)/);
  if (weekdayMatch) {
    const parts = weekdayMatch[1].split(/[,\s]+/).filter(Boolean);
    const days = parts.map(p => dayAbbrevs[p]).filter(d => d !== undefined);
    if (days.length > 0) {
      return { type: 'weekly', interval: 1, weekdays: days.join(',') };
    }
  }

  // Simple patterns
  if (s.includes('day') || s === 'daily') return { type: 'daily', interval: 1, weekdays: null };
  if (s.includes('week') || s === 'weekly') return { type: 'weekly', interval: 1, weekdays: null };
  if (s.includes('month') || s === 'monthly') return { type: 'monthly', interval: 1, weekdays: null };
  if (s.includes('year') || s === 'yearly' || s === 'annually') return { type: 'yearly', interval: 1, weekdays: null };

  return { type: 'daily', interval: 1, weekdays: null };
}

function colorToHex(color) {
  if (!color) return '#6366f1';
  if (color.startsWith('#')) return color;
  return TODOIST_COLORS[color] || '#6366f1';
}

// POST /api/todoist/sync — full import from Todoist
router.post('/sync', async (req, res) => {
  try {
    const { apiToken } = req.body;
    if (!apiToken) {
      return res.status(400).json({ error: 'apiToken is required in request body' });
    }

    const client = new TodoistClient(apiToken);
    const userId = req.user.id;

    const { projects, tasks, labels, sections, comments } = await client.fetchAll();

    const stats = { projects: 0, tasks: 0, labels: 0, sections: 0, schedules: 0, comments: 0 };

    // Map todoist project IDs to local IDs
    const projectMap = {};

    // Import projects
    for (const p of projects) {
      const localId = uuidv4();
      projectMap[p.id] = localId;
      const existing = await get('SELECT id FROM projects WHERE user_id = ? AND name = ?', [userId, p.name]);
      if (existing) {
        projectMap[p.id] = existing.id;
        continue;
      }
      await run(
        `INSERT INTO projects (id, user_id, name, color, is_favorite, sort_order, is_inbox)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [localId, userId, p.name, colorToHex(p.color), p.is_favorite ? 1 : 0, p.order || 0, p.is_inbox_project ? 1 : 0]
      );
      stats.projects++;
    }

    // Import sections
    const sectionMap = {};
    for (const s of sections) {
      const localId = uuidv4();
      sectionMap[s.id] = localId;
      const projId = projectMap[s.project_id];
      if (!projId) continue;
      const existing = await get('SELECT id FROM sections WHERE project_id = ? AND name = ?', [projId, s.name]);
      if (existing) {
        sectionMap[s.id] = existing.id;
        continue;
      }
      await run(
        `INSERT INTO sections (id, project_id, user_id, name, sort_order)
         VALUES (?, ?, ?, ?, ?)`,
        [localId, projId, userId, s.name, s.order || 0]
      );
      stats.sections++;
    }

    // Import labels
    const labelMap = {};
    for (const l of labels) {
      const localId = uuidv4();
      labelMap[l.id] = localId;
      const existing = await get('SELECT id FROM labels WHERE user_id = ? AND name = ?', [userId, l.name]);
      if (existing) {
        labelMap[l.id] = existing.id;
        continue;
      }
      await run(
        `INSERT INTO labels (id, user_id, name, color, sort_order, is_favorite)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [localId, userId, l.name, colorToHex(l.color), l.order || 0, l.is_favorite ? 1 : 0]
      );
      stats.labels++;
    }

    // Import tasks (two passes: first create all, then link parents)
    const taskMap = {}; // todoist task id -> local task id
    for (const t of tasks) {
      const projId = projectMap[t.project_id] || null;
      const secId = sectionMap[t.section_id] || null;
      const existing = await get('SELECT id FROM tasks WHERE user_id = ? AND title = ? AND project_id = ?', [userId, t.content, projId]);
      if (existing) {
        taskMap[t.id] = existing.id;
        continue;
      }

      const taskId = uuidv4();
      taskMap[t.id] = taskId;
      const dueDate = t.due ? t.due.date : null;
      const dueTime = t.due && t.due.datetime ? t.due.datetime.split('T')[1]?.replace('Z', '') : null;
      const recurring = t.due && t.due.is_recurring ? t.due.string : null;

      await run(
        `INSERT INTO tasks (id, user_id, project_id, section_id, title, description, priority, due_date, due_time, completed, sort_order, recurring)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [taskId, userId, projId, secId, t.content, t.description || '', mapPriority(t.priority), dueDate, dueTime, 0, t.order || 0, recurring]
      );

      // Link labels
      if (t.labels && t.labels.length > 0) {
        for (const labelName of t.labels) {
          const labelRow = await get('SELECT id FROM labels WHERE user_id = ? AND name = ?', [userId, labelName]);
          if (labelRow) {
            await run('INSERT OR IGNORE INTO task_labels (task_id, label_id) VALUES (?, ?)', [taskId, labelRow.id]);
          }
        }
      }

      // Sync recurring schedule into recurring_tasks table
      if (recurring) {
        const recurId = uuidv4();
        const pattern = parseRecurringPattern(recurring);
        await run(
          `INSERT INTO recurring_tasks (id, user_id, task_template_id, pattern, interval_value, weekdays, next_due)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [recurId, userId, taskId, pattern.type, pattern.interval, pattern.weekdays, dueDate]
        );
        // Link task to its recurring_tasks entry
        await run('UPDATE tasks SET recurring_id = ? WHERE id = ?', [recurId, taskId]);
        stats.schedules = (stats.schedules || 0) + 1;
      }

      stats.tasks++;
    }

    // Second pass: link parent_id for subtasks
    for (const t of tasks) {
      if (t.parent_id && taskMap[t.parent_id] && taskMap[t.id]) {
        await run('UPDATE tasks SET parent_id = ? WHERE id = ?', [taskMap[t.parent_id], taskMap[t.id]]);
      }
    }

    // Import comments
    if (comments && comments.length > 0) {
      for (const c of comments) {
        const localTaskId = taskMap[c.task_id];
        if (!localTaskId) continue;
        const existing = await get('SELECT id FROM comments WHERE task_id = ? AND content = ?', [localTaskId, c.content]);
        if (existing) continue;
        const commentId = uuidv4();
        await run(
          'INSERT INTO comments (id, task_id, user_id, content, created_at) VALUES (?, ?, ?, ?, ?)',
          [commentId, localTaskId, userId, c.content, c.posted_at || new Date().toISOString()]
        );
        stats.comments++;
      }
    }

    res.json({
      message: 'Todoist sync completed successfully',
      stats,
      total: stats.projects + stats.tasks + stats.labels + stats.sections
    });
  } catch (err) {
    console.error('POST /todoist/sync error:', err);
    if (err.status === 401 || err.status === 403) {
      return res.status(401).json({ error: 'Invalid Todoist API token' });
    }
    res.status(500).json({ error: 'Todoist sync failed: ' + err.message });
  }
});

// GET /api/todoist/tasks — fetch tasks from Todoist (read-only, no DB write)
router.get('/tasks', async (req, res) => {
  try {
    const apiToken = req.query.token || req.headers['x-todoist-token'];
    if (!apiToken) {
      return res.status(400).json({ error: 'token query param or x-todoist-token header required' });
    }

    const client = new TodoistClient(apiToken);
    const params = {};
    if (req.query.project_id) params.project_id = req.query.project_id;
    if (req.query.label) params.label = req.query.label;
    if (req.query.filter) params.filter = req.query.filter;

    const tasks = await client.getTasks(params);
    res.json({ tasks, count: tasks.length });
  } catch (err) {
    console.error('GET /todoist/tasks error:', err);
    if (err.status === 401 || err.status === 403) {
      return res.status(401).json({ error: 'Invalid Todoist API token' });
    }
    res.status(500).json({ error: 'Failed to fetch Todoist tasks: ' + err.message });
  }
});

// POST /api/todoist/tasks/sync — sync only tasks from Todoist into local DB
router.post('/tasks/sync', async (req, res) => {
  try {
    const { apiToken, project_id } = req.body;
    if (!apiToken) {
      return res.status(400).json({ error: 'apiToken is required in request body' });
    }

    const client = new TodoistClient(apiToken);
    const userId = req.user.id;

    const params = {};
    if (project_id) params.project_id = project_id;

    const tasks = await client.getTasks(params);
    let synced = 0;
    let skipped = 0;
    let scheduleSynced = 0;

    for (const t of tasks) {
      // Resolve local project ID from todoist project_id
      const projRow = t.project_id
        ? await get('SELECT id FROM projects WHERE user_id = ? AND todoist_id = ?', [userId, t.project_id])
          || await get('SELECT id FROM projects WHERE user_id = ? ORDER BY sort_order LIMIT 1', [userId])
        : null;
      const projId = projRow ? projRow.id : null;

      // Resolve local section ID
      const secRow = t.section_id
        ? await get('SELECT id FROM sections WHERE user_id = ? AND todoist_id = ?', [userId, t.section_id])
        : null;
      const secId = secRow ? secRow.id : null;

      // Skip if task already exists (match by title + project)
      const existing = await get('SELECT id FROM tasks WHERE user_id = ? AND title = ? AND project_id = ?', [userId, t.content, projId]);
      if (existing) { skipped++; continue; }

      const taskId = uuidv4();
      const dueDate = t.due ? t.due.date : null;
      const dueTime = t.due && t.due.datetime ? t.due.datetime.split('T')[1]?.replace('Z', '') : null;
      const recurring = t.due && t.due.is_recurring ? t.due.string : null;

      await run(
        `INSERT INTO tasks (id, user_id, project_id, section_id, title, description, priority, due_date, due_time, completed, sort_order, recurring)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [taskId, userId, projId, secId, t.content, t.description || '', mapPriority(t.priority), dueDate, dueTime, 0, t.order || 0, recurring]
      );

      // Link labels
      if (t.labels && t.labels.length > 0) {
        for (const labelName of t.labels) {
          const labelRow = await get('SELECT id FROM labels WHERE user_id = ? AND name = ?', [userId, labelName]);
          if (labelRow) {
            await run('INSERT OR IGNORE INTO task_labels (task_id, label_id) VALUES (?, ?)', [taskId, labelRow.id]);
          }
        }
      }

      // Sync recurring schedule
      if (recurring) {
        const recurId = uuidv4();
        const pattern = parseRecurringPattern(recurring);
        await run(
          `INSERT INTO recurring_tasks (id, user_id, task_template_id, pattern, interval_value, weekdays, next_due)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [recurId, userId, taskId, pattern.type, pattern.interval, pattern.weekdays, dueDate]
        );
        await run('UPDATE tasks SET recurring_id = ? WHERE id = ?', [recurId, taskId]);
        scheduleSynced++;
      }

      synced++;
    }

    res.json({
      message: 'Task sync completed',
      stats: { synced, skipped, schedules: scheduleSynced, total: tasks.length }
    });
  } catch (err) {
    console.error('POST /todoist/tasks/sync error:', err);
    if (err.status === 401 || err.status === 403) {
      return res.status(401).json({ error: 'Invalid Todoist API token' });
    }
    res.status(500).json({ error: 'Task sync failed: ' + err.message });
  }
});

// GET /api/todoist/preview — preview what would be synced without importing
router.get('/preview', async (req, res) => {
  try {
    const apiToken = req.query.token || req.headers['x-todoist-token'];
    if (!apiToken) {
      return res.status(400).json({ error: 'token query param or x-todoist-token header required' });
    }

    const client = new TodoistClient(apiToken);
    const data = await client.fetchAll();

    res.json({
      projects: data.projects.length,
      tasks: data.tasks.length,
      labels: data.labels.length,
      sections: data.sections.length,
      projectNames: data.projects.map(p => p.name),
    });
  } catch (err) {
    console.error('GET /todoist/preview error:', err);
    if (err.status === 401 || err.status === 403) {
      return res.status(401).json({ error: 'Invalid Todoist API token' });
    }
    res.status(500).json({ error: 'Preview failed: ' + err.message });
  }
});

module.exports = router;
