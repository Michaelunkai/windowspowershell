---
pdf_options:
  margin: 7mm
  format: A4
  printBackground: true
---

<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
  body { font-family: 'Inter', sans-serif; color: #2d3748; line-height: 1.35; font-size: 9.5px; }
  h1 { font-size: 26px; font-weight: 700; color: #1a365d; margin: 0 0 3px 0; }
  .subtitle { font-size: 12px; color: #3182ce; font-weight: 600; margin-bottom: 5px; }
  .contact { font-size: 9px; color: #4a5568; margin-bottom: 10px; }
  .contact a { color: #3182ce; text-decoration: none; }
  h2 { font-size: 11px; font-weight: 700; color: #fff; background: linear-gradient(135deg, #1a365d 0%, #2c5282 100%); padding: 4px 10px; margin: 8px 0 5px 0; border-radius: 3px; text-transform: uppercase; letter-spacing: 1px; }
  .skills-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 3px 15px; }
  .skill-row { display: flex; align-items: baseline; padding: 2px 0; border-bottom: 1px solid #e2e8f0; }
  .skill-label { font-weight: 600; color: #2c5282; min-width: 70px; font-size: 9px; }
  .skill-items { color: #4a5568; font-size: 9px; }
  .expert { background: #c6f6d5; color: #276749; padding: 0px 4px; border-radius: 2px; font-size: 7px; font-weight: 600; margin-left: 3px; }
  .job { margin-bottom: 6px; }
  .job-header { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 3px; }
  .job-title { font-weight: 700; color: #1a365d; font-size: 11px; }
  .job-company { color: #3182ce; font-weight: 600; }
  .job-date { color: #718096; font-size: 9px; }
  ul { margin: 0; padding-left: 12px; }
  li { margin-bottom: 1px; color: #4a5568; font-size: 9px; }
  .projects-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 5px; }
  .project { background: #f7fafc; padding: 5px 6px; border-radius: 3px; border-left: 2px solid #3182ce; }
  .project-name { font-weight: 600; color: #1a365d; font-size: 9px; }
  .project-tech { font-size: 7px; color: #3182ce; margin-top: 1px; }
  .project-desc { font-size: 8px; color: #718096; margin-top: 1px; }
  .summary { background: #ebf8ff; padding: 6px 10px; border-radius: 3px; color: #2c5282; font-size: 9.5px; margin-bottom: 3px; border-left: 3px solid #3182ce; }
  .education-item { background: #f7fafc; padding: 4px 8px; border-radius: 3px; font-size: 9px; }
  .header { display: flex; align-items: center; gap: 15px; margin-bottom: 8px; }
  .photo { width: 75px; height: 75px; border-radius: 50%; object-fit: cover; border: 3px solid #3182ce; }
  .header-text { flex: 1; }
</style>

<div class="header">
<img src="me.jpg" class="photo">
<div class="header-text">
<h1>Michael Fedorovsky</h1>
<div class="subtitle">DevOps Engineer | System Administrator | AI Automation Specialist</div>
<div class="contact">
📍 Bat Yam, Israel  •  📱 054-763-2418  •  ✉️ michaelovsky5@gmail.com  •  <a href="https://linkedin.com/in/michael-fedorovsky-b26099278">LinkedIn</a>  •  <a href="https://github.com/Michaelunkai">GitHub (50+ repos)</a>
</div>
</div>
</div>

<div class="summary">
Results-driven DevOps Engineer with expertise in cloud infrastructure, CI/CD automation, container orchestration, and monitoring systems. Built 50+ automation tools and production systems. Expert in AWS, Docker, Prometheus/Grafana stack, and Python/Bash scripting.
</div>

<h2>🛠️ Technical Skills</h2>

<div class="skills-grid">
<div class="skill-row"><span class="skill-label">Cloud</span><span class="skill-items">AWS, Azure, Vercel<span class="expert">EXPERT</span> • GCP, Cloudflare (Proficient)</span></div>
<div class="skill-row"><span class="skill-label">Containers</span><span class="skill-items">Docker<span class="expert">EXPERT</span> • Kubernetes, Helm, Podman, Rancher, ArgoCD</span></div>
<div class="skill-row"><span class="skill-label">CI/CD</span><span class="skill-items">GitHub Actions<span class="expert">EXPERT</span> • Terraform, GitLab CI, Jenkins</span></div>
<div class="skill-row"><span class="skill-label">IaC</span><span class="skill-items">Terraform, Ansible (Proficient) • Pulumi, Packer</span></div>
<div class="skill-row"><span class="skill-label">Monitoring</span><span class="skill-items">Prometheus, Grafana, Datadog, ELK, Loki, PagerDuty, Jaeger, Splunk<span class="expert">EXPERT</span></span></div>
<div class="skill-row"><span class="skill-label">Languages</span><span class="skill-items">Python, Bash, PowerShell, JavaScript<span class="expert">EXPERT</span> • TypeScript, Go, SQL</span></div>
<div class="skill-row"><span class="skill-label">Databases</span><span class="skill-items">PostgreSQL, MySQL, MongoDB, Redis<span class="expert">EXPERT</span> • Elasticsearch</span></div>
<div class="skill-row"><span class="skill-label">Security</span><span class="skill-items">Vault, Trivy, Snyk, OPA, Keycloak, SonarQube, Falco, nmap (Proficient)</span></div>
<div class="skill-row"><span class="skill-label">Web/Proxy</span><span class="skill-items">Nginx, Traefik<span class="expert">EXPERT</span> • HAProxy, Envoy, Kong</span></div>
<div class="skill-row"><span class="skill-label">OS/Virt</span><span class="skill-items">Linux, Ubuntu, Alpine, Windows Server, WSL, KVM, Proxmox<span class="expert">EXPERT</span></span></div>
<div class="skill-row"><span class="skill-label">Testing</span><span class="skill-items">pytest, Playwright<span class="expert">EXPERT</span> • Jest, k6</span></div>
<div class="skill-row"><span class="skill-label">Tools</span><span class="skill-items">Git, GitHub, Jira, Slack<span class="expert">EXPERT</span> • GitLab, Confluence</span></div>
</div>

<h2>💼 Professional Experience</h2>

<div class="job">
<div class="job-header">
<span><span class="job-title">DevOps Engineer</span> <span class="job-company">@ TovTech</span></span>
<span class="job-date">1 Year</span>
</div>

- Architected **production & staging environments** on Webdock with Cloudflare CDN, SSL, DDoS protection
- Designed **CI/CD pipelines** (GitHub Actions): lint → test → Docker build → DockerHub → auto-deploy
- Built **multi-stage Dockerfiles** optimizing image sizes by 60%, implemented health checks & auto-recovery
- Deployed **monitoring stack**: Prometheus metrics, Grafana dashboards, ELK log aggregation
- Managed **PostgreSQL** with migrations, replication, automated backups; achieved 99.9% uptime
</div>

<h2>🚀 Featured Projects (50+ Total)</h2>

<div class="projects-grid">
<div class="project">
<div class="project-name">TovPlay Platform</div>
<div class="project-tech">Flask • PostgreSQL • Socket.IO • Docker</div>
<div class="project-desc">Gaming backend with JWT auth, Discord OAuth, real-time features, full CI/CD pipeline</div>
</div>
<div class="project">
<div class="project-name">Container Security Scanner</div>
<div class="project-tech">Trivy • Docker • Python</div>
<div class="project-desc">Automated vulnerability scanning for Docker images with severity reporting</div>
</div>
<div class="project">
<div class="project-name">API Gateway Platform</div>
<div class="project-tech">TypeScript • Node.js • Redis</div>
<div class="project-desc">API gateway with routing, rate limiting, caching, and JWT authentication</div>
</div>
<div class="project">
<div class="project-name">IoT Device Manager</div>
<div class="project-tech">MQTT • Node.js • MongoDB</div>
<div class="project-desc">Fleet management platform for IoT devices with real-time monitoring</div>
</div>
<div class="project">
<div class="project-name">DB Performance Monitor</div>
<div class="project-tech">PostgreSQL • Grafana • Python</div>
<div class="project-desc">Database health monitoring with query analysis and alerting dashboards</div>
</div>
<div class="project">
<div class="project-name">MCP On-Demand</div>
<div class="project-tech">PowerShell • AI</div>
<div class="project-desc">Dynamic AI tool server management with runtime loading/unloading</div>
</div>
<div class="project">
<div class="project-name">Web Scraping Platform</div>
<div class="project-tech">Scrapy • Python • Redis</div>
<div class="project-desc">Distributed web scraping with job queues and proxy rotation</div>
</div>
<div class="project">
<div class="project-name">Trading Bot Platform</div>
<div class="project-tech">Python • WebSocket • APIs</div>
<div class="project-desc">Cryptocurrency trading automation with real-time market data integration</div>
</div>
<div class="project">
<div class="project-name">ArgoCD GitOps</div>
<div class="project-tech">Kubernetes • ArgoCD • Helm</div>
<div class="project-desc">GitOps infrastructure with automated deployments and rollback capabilities</div>
</div>
<div class="project">
<div class="project-name">Dev Environment Manager</div>
<div class="project-tech">Docker • CLI • Bash</div>
<div class="project-desc">Containerized development environments with one-command setup</div>
</div>
<div class="project">
<div class="project-name">Telegram Bots Suite</div>
<div class="project-tech">Python • API • Docker</div>
<div class="project-desc">Multiple automation bots for notifications, trading alerts, and monitoring</div>
</div>
<div class="project">
<div class="project-name">WSL2 Automation</div>
<div class="project-tech">PowerShell • Bash</div>
<div class="project-desc">Complete WSL2 Ubuntu setup automation with dev tools and config</div>
</div>
<div class="project">
<div class="project-name">Log Analysis AI</div>
<div class="project-tech">Python • ELK • AI</div>
<div class="project-desc">AI-powered log analysis with anomaly detection and pattern recognition</div>
</div>
<div class="project">
<div class="project-name">Network Traffic Analyzer</div>
<div class="project-tech">Python • Wireshark • Grafana</div>
<div class="project-desc">Network monitoring and traffic analysis with visualization dashboards</div>
</div>
<div class="project">
<div class="project-name">Automated Testing Suite</div>
<div class="project-tech">Playwright • pytest • CI/CD</div>
<div class="project-desc">E2E testing framework with parallel execution and GitHub Actions integration</div>
</div>
</div>

<h2>🎓 Education</h2>

<div class="education-item">
<strong>Data Analysis Program</strong> — TovTech (1 Year Intensive Course)
</div>
<div class="education-item" style="margin-top: 4px;">
<strong>Engineering Preparatory Year</strong> — Ariel University (Physics, Mathematics, English)
</div>
