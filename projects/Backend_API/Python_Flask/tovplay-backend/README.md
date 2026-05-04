# TovPlay Backend

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker Hub](https://img.shields.io/badge/Docker-Hub-blue?logo=docker)](https://hub.docker.com/r/tovtech/tovplaybackend)

Modern backend API for the TovPlay gaming platform built with Flask, PostgreSQL, and Socket.IO.

## 🚀 Quick Start

### Local Development (Recommended)

```bash
cd F:\tovplay\tovplay-backend
python -m venv venv
.\venv\Scripts\activate  # Windows
pip install -r requirements.txt
cp .env.template .env    # Configure with your credentials
flask run --host=0.0.0.0 --port=5001 --debug
```

Access: http://localhost:5001/health

### Docker Development

```bash
# Using external database (default)
docker-compose up backend

# Using local PostgreSQL container
docker-compose --profile local-db up
```

## 🛠️ Tech Stack

- **Framework**: Flask 3.1+, Python 3.11
- **Database**: PostgreSQL 17.4 with SQLAlchemy 2.0+
- **Real-time**: Socket.IO
- **Authentication**: JWT tokens with Flask-JWT-Extended
- **Containerization**: Docker multi-stage builds
- **CI/CD**: GitHub Actions → Docker Hub → Servers

## 📋 Configuration

1. **Copy environment template**:
   ```bash
   cp .env.template .env
   ```

2. **Edit .env** with your configuration:
   - For **local dev**: Uncomment local development section
   - For **production**: Uncomment production section
   - For **staging**: Uncomment staging section

3. **Database**: Project uses external PostgreSQL at 45.148.28.196 by default. See .env.template for connection details.

## 📚 API Endpoints

- **Health**: `GET /health`
- **Users**: `/api/users`, `/api/users/{id}`
- **Games**: `/api/games`, `/api/games/{id}`
- **Game Requests**: `/api/game-requests`
- **Sessions**: `/api/sessions`
- **Availability**: `/api/availability`
- **Discord Auth**: `/api/discord/callback`

Full documentation: See `/CLAUDE.md`

## 🔄 CI/CD

GitHub Actions automatically handles deployment:

- **Push to `main`** → Deploys to **Staging** (92.113.144.59)
- **Builds Docker image** → Pushes to `tovtech/tovplaybackend:latest`
- **SSH deployment** → Restarts container on server

### Required GitHub Secrets

Add to repository settings (Settings > Secrets and variables > Actions):

| Secret | Value |
|--------|-------|
| `DOCKERHUB_TOKEN` | Docker Hub access token (generate at hub.docker.com/settings/security) |
| `SSH_PRIVATE_KEY` | Server SSH private key |
| `SERVER_IP` | Server IP address |
| `SERVER_USER` | SSH username |

### Manual Deployment

**Production** (193.181.213.220):
```bash
ssh admin@193.181.213.220  # Password: <REDACTED_TOVTECH_SERVER_PASSWORD>
cd /home/admin/tovplay
docker pull tovtech/tovplaybackend:latest
docker-compose up -d --force-recreate backend
```

**Staging** (92.113.144.59):
```bash
ssh admin@92.113.144.59  # Password: <REDACTED_TOVTECH_SERVER_PASSWORD>
cd /home/admin/tovplay
docker pull tovtech/tovplaybackend:staging
docker-compose up -d --force-recreate backend
```

## 🧪 Testing

```bash
pytest
pytest --cov=src tests/
pytest tests/test_routes.py
```

## 📁 Project Structure

```
tovplay-backend/
├─ src/
│  ├─ api/              # API endpoints
│  ├─ app/              # Flask app & routes
│  ├─ database/         # Models & migrations
│  ├─ services/         # Business logic
│  └─ utils/            # Helpers
├─ .env.template        # Environment config template
├─ docker-compose.yml   # Unified Docker Compose (local/staging/prod)
├─ requirements.txt     # Python dependencies
└─ wsgi.py              # Production entry point
```

## 📞 Support

- **Team**: See `/CLAUDE.md` for team contacts
- **Issues**: Open an issue in this repository
- **Jira**: https://tovplay.atlassian.net/jira/software/projects/TVPL/boards/1

## 🔗 Links

- **Production**: https://app.tovplay.org
- **Staging**: https://staging.tovplay.org
- **Docker Hub**: https://hub.docker.com/r/tovtech/tovplaybackend
- **Monitoring**: http://193.181.213.220:3002 (Grafana)

---

**Built by the TovPlay Team** | For detailed architecture, credentials, and DevOps info, see `/CLAUDE.md`
