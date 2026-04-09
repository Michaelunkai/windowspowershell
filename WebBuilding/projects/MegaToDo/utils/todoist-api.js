/**
 * Todoist REST API v2 Client
 * Handles authentication and CRUD operations against the official Todoist API.
 * Docs: https://developer.todoist.com/rest/v2
 */

const BASE_URL = 'https://api.todoist.com/rest/v2';

class TodoistClient {
  constructor(apiToken) {
    if (!apiToken) throw new Error('Todoist API token is required');
    this.token = apiToken;
  }

  async _request(method, endpoint, body = null) {
    const url = `${BASE_URL}${endpoint}`;
    const headers = {
      'Authorization': `Bearer ${this.token}`,
      'Content-Type': 'application/json',
    };

    const opts = { method, headers };
    if (body && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
      opts.body = JSON.stringify(body);
    }

    const res = await fetch(url, opts);

    if (res.status === 204) return null; // No content (e.g. DELETE success)

    if (!res.ok) {
      const text = await res.text();
      const err = new Error(`Todoist API ${method} ${endpoint} failed: ${res.status} ${text}`);
      err.status = res.status;
      throw err;
    }

    return res.json();
  }

  // ── Projects ──────────────────────────────────────────────
  async getProjects() {
    return this._request('GET', '/projects');
  }

  async getProject(id) {
    return this._request('GET', `/projects/${id}`);
  }

  // ── Sections ──────────────────────────────────────────────
  async getSections(projectId) {
    const query = projectId ? `?project_id=${projectId}` : '';
    return this._request('GET', `/sections${query}`);
  }

  // ── Tasks ─────────────────────────────────────────────────
  async getTasks(params = {}) {
    const query = new URLSearchParams();
    if (params.project_id) query.set('project_id', params.project_id);
    if (params.section_id) query.set('section_id', params.section_id);
    if (params.label) query.set('label', params.label);
    if (params.filter) query.set('filter', params.filter);
    const qs = query.toString();
    return this._request('GET', `/tasks${qs ? '?' + qs : ''}`);
  }

  async getTask(id) {
    return this._request('GET', `/tasks/${id}`);
  }

  // ── Labels ────────────────────────────────────────────────
  async getLabels() {
    return this._request('GET', '/labels');
  }

  // ── Comments ──────────────────────────────────────────────
  async getComments(taskId) {
    return this._request('GET', `/comments?task_id=${taskId}`);
  }

  // ── Collaborators ────────────────────────────────────────
  async getCollaborators(projectId) {
    return this._request('GET', `/projects/${projectId}/collaborators`);
  }

  // ── Convenience: fetch everything ─────────────────────────
  async fetchAll() {
    const [projects, tasks, labels, sections] = await Promise.all([
      this.getProjects(),
      this.getTasks(),
      this.getLabels(),
      this.getSections(),
    ]);

    // Fetch comments for all tasks (in batches to avoid rate limits)
    const comments = [];
    for (const t of tasks) {
      try {
        const taskComments = await this.getComments(t.id);
        if (taskComments && taskComments.length > 0) {
          comments.push(...taskComments.map(c => ({ ...c, task_id: t.id })));
        }
      } catch (e) {
        // Some tasks may not allow comments; skip silently
      }
    }

    return { projects, tasks, labels, sections, comments };
  }
}

module.exports = { TodoistClient };
