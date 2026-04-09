export const portfolio = {
  personal: {
    name: "Michael Fedorovsky",
    title: "DevOps Engineer | System Administrator | AI Automation Specialist",
    yearsExperience: 3,
    brand: "MichaelDev",
    tagline: "Infrastructure That Never Fails",
    bio: "DevOps engineer with a proven track record of building scalable, secure infrastructure that drives business results. Specialized in cloud automation, CI/CD pipelines, container orchestration, and cost optimization. Delivered 50+ production tools, reduced cloud costs by 40%, and maintained 99.9% uptime across AWS, Azure, and GCP. Passionate about solving complex technical challenges and empowering development teams with robust, automated workflows.",
    journeyBio: `Started as a passionate self-taught developer, rapidly evolved into a full-stack DevOps engineer obsessed with automation and reliability. Over 3 years, I've built 50+ production tools, managed infrastructure serving thousands of users, and maintained 99.9% uptime across multi-cloud environments.

At TovTech, I architected cloud infrastructure with Cloudflare CDN integration, automated end-to-end deployment workflows with GitHub Actions, and deployed comprehensive observability stacks (Prometheus, Grafana, ELK). Led security initiatives including container scanning with Trivy, implemented GitOps with ArgoCD, and reduced deployment times by 80% through Infrastructure as Code.

I thrive on solving complex infrastructure challenges, optimizing costs, and building systems that scale effortlessly. Whether it's Kubernetes orchestration, CI/CD pipelines, or AI automation—I deliver production-ready solutions that just work.`,
    email: "michaelovsky5@gmail.com",
    phone: "054-763-2418",
    location: "Bat Yam, Israel",
    avatar: "/images/avatar.jpg",
  },
  socials: {
    github: "https://github.com/Michaelunkai",
    linkedin: "https://linkedin.com/in/michael-fedorovsky-b26099278",
  },
  resumes: [
    { name: "DevOps Engineer", file: "/resumes/Michael_Fedorovsky_DevOps.pdf" },
    { name: "System Administrator", file: "/resumes/Michael_Fedorovsky_SysAdmin.pdf" },
    { name: "Cloud Engineer", file: "/resumes/Michael_Fedorovsky_Cloud_Engineer.pdf" },
    { name: "DevSecOps Engineer", file: "/resumes/Michael_Fedorovsky_DevSecOps.pdf" },
    { name: "Computer Technician", file: "/resumes/Michael_Fedorovsky_Computer_Technician.pdf" },
  ],
  stats: [
    { value: "50+", label: "Automation Tools Built" },
    { value: "99.9%", label: "Uptime Achieved" },
    { value: "3+", label: "Years Experience" },
    { value: "50+", label: "GitHub Repositories" },
  ],
  techStack: [
    // Cloud Platforms
    { name: "AWS", icon: "SiAmazonwebservices" },
    { name: "Azure", icon: "SiMicrosoftazure" },
    { name: "Google Cloud", icon: "SiGooglecloud" },
    { name: "DigitalOcean", icon: "SiDigitalocean" },
    { name: "Cloudflare", icon: "SiCloudflare" },
    { name: "Vercel", icon: "SiVercel" },
    { name: "Netlify", icon: "SiNetlify" },
    
    // Containers & Orchestration
    { name: "Docker", icon: "SiDocker" },
    { name: "Kubernetes", icon: "SiKubernetes" },
    { name: "Helm", icon: "SiHelm" },
    { name: "ArgoCD", icon: "SiArgo" },
    { name: "Rancher", icon: "SiRancher" },
    { name: "Podman", icon: "SiPodman" },
    { name: "containerd", icon: "SiContainerd" },
    
    // IaC & Configuration Management
    { name: "Terraform", icon: "SiTerraform" },
    { name: "Ansible", icon: "SiAnsible" },
    { name: "Pulumi", icon: "SiPulumi" },
    { name: "CloudFormation", icon: "SiAmazonaws" },
    { name: "Vagrant", icon: "SiVagrant" },
    { name: "Chef", icon: "SiChef" },
    { name: "Puppet", icon: "SiPuppet" },
    
    // CI/CD
    { name: "GitHub Actions", icon: "SiGithubactions" },
    { name: "GitLab CI", icon: "SiGitlab" },
    { name: "Jenkins", icon: "SiJenkins" },
    { name: "CircleCI", icon: "SiCircleci" },
    { name: "Travis CI", icon: "SiTravisci" },
    { name: "TeamCity", icon: "SiTeamcity" },
    { name: "Drone", icon: "SiDrone" },
    
    // Monitoring & Observability
    { name: "Prometheus", icon: "SiPrometheus" },
    { name: "Grafana", icon: "SiGrafana" },
    { name: "Datadog", icon: "SiDatadog" },
    { name: "New Relic", icon: "SiNewrelic" },
    { name: "Jaeger", icon: "SiJaeger" },
    { name: "Zipkin", icon: "SiZipkin" },
    { name: "Sentry", icon: "SiSentry" },
    
    // Logging
    { name: "Elasticsearch", icon: "SiElasticsearch" },
    { name: "Logstash", icon: "SiLogstash" },
    { name: "Kibana", icon: "SiKibana" },
    { name: "Fluentd", icon: "SiFluentd" },
    { name: "Loki", icon: "SiGrafana" },
    { name: "Splunk", icon: "SiSplunk" },
    
    // Databases
    { name: "PostgreSQL", icon: "SiPostgresql" },
    { name: "MySQL", icon: "SiMysql" },
    { name: "MongoDB", icon: "SiMongodb" },
    { name: "Redis", icon: "SiRedis" },
    { name: "Cassandra", icon: "SiApachecassandra" },
    { name: "DynamoDB", icon: "SiAmazondynamodb" },
    { name: "MariaDB", icon: "SiMariadb" },
    
    // Message Queues & Streaming
    { name: "RabbitMQ", icon: "SiRabbitmq" },
    { name: "Apache Kafka", icon: "SiApachekafka" },
    { name: "NATS", icon: "SiNats" },
    { name: "ActiveMQ", icon: "SiApache" },
    { name: "Amazon SQS", icon: "SiAmazonaws" },
    
    // Web Servers & Reverse Proxies
    { name: "Nginx", icon: "SiNginx" },
    { name: "Apache", icon: "SiApache" },
    { name: "HAProxy", icon: "SiHaproxy" },
    { name: "Traefik", icon: "SiTraefik" },
    { name: "Caddy", icon: "SiCaddy" },
    { name: "Envoy", icon: "SiEnvoyproxy" },
    
    // Programming & Scripting
    { name: "Python", icon: "SiPython" },
    { name: "Bash", icon: "SiGnubash" },
    { name: "PowerShell", icon: "SiPowershell" },
    { name: "Go", icon: "SiGo" },
    { name: "Node.js", icon: "SiNodedotjs" },
    { name: "TypeScript", icon: "SiTypescript" },
    { name: "C#", icon: "SiCsharp" },
    
    // Version Control
    { name: "Git", icon: "SiGit" },
    { name: "GitHub", icon: "SiGithub" },
    { name: "GitLab", icon: "SiGitlab" },
    { name: "Bitbucket", icon: "SiBitbucket" },
    
    // Operating Systems
    { name: "Linux", icon: "SiLinux" },
    { name: "Ubuntu", icon: "SiUbuntu" },
    { name: "CentOS", icon: "SiCentos" },
    { name: "Debian", icon: "SiDebian" },
    { name: "Red Hat", icon: "SiRedhat" },
    { name: "Alpine Linux", icon: "SiAlpinelinux" },
    { name: "Windows Server", icon: "SiWindows" },
    
    // Security & Secrets
    { name: "HashiCorp Vault", icon: "SiVault" },
    { name: "Trivy", icon: "SiTrivy" },
    { name: "Snyk", icon: "SiSnyk" },
    { name: "SonarQube", icon: "SiSonarqube" },
    { name: "OWASP ZAP", icon: "SiOwasp" },
    { name: "Aqua Security", icon: "SiAqua" },
    
    // Service Mesh
    { name: "Istio", icon: "SiIstio" },
    { name: "Linkerd", icon: "SiLinkerd" },
    { name: "Consul", icon: "SiConsul" },
    
    // API & Integration
    { name: "REST APIs", icon: "SiPostman" },
    { name: "GraphQL", icon: "SiGraphql" },
    { name: "gRPC", icon: "SiGrpc" },
    { name: "Swagger", icon: "SiSwagger" },
    { name: "Postman", icon: "SiPostman" },
    
    // Testing
    { name: "Jest", icon: "SiJest" },
    { name: "Pytest", icon: "SiPytest" },
    { name: "Selenium", icon: "SiSelenium" },
    { name: "Cypress", icon: "SiCypress" },
    { name: "JUnit", icon: "SiJunit5" },
    
    // Build Tools
    { name: "Maven", icon: "SiApachemaven" },
    { name: "Gradle", icon: "SiGradle" },
    { name: "npm", icon: "SiNpm" },
    { name: "Yarn", icon: "SiYarn" },
    { name: "Make", icon: "SiGnubash" },
    
    // Package Managers
    { name: "Helm", icon: "SiHelm" },
    { name: "apt", icon: "SiDebian" },
    { name: "yum", icon: "SiRedhat" },
    { name: "Chocolatey", icon: "SiChocolatey" },
    { name: "Homebrew", icon: "SiHomebrew" },
    
    // Serverless
    { name: "AWS Lambda", icon: "SiAwslambda" },
    { name: "Azure Functions", icon: "SiMicrosoftazure" },
    { name: "Google Cloud Functions", icon: "SiGooglecloud" },
    { name: "Serverless Framework", icon: "SiServerless" },
    
    // Frameworks & Runtime
    { name: "Flask", icon: "SiFlask" },
    { name: "FastAPI", icon: "SiFastapi" },
    { name: "Express.js", icon: "SiExpress" },
    { name: ".NET", icon: "SiDotnet" },
    { name: "Spring Boot", icon: "SiSpringboot" },
    
    // Virtualization
    { name: "VMware", icon: "SiVmware" },
    { name: "VirtualBox", icon: "SiVirtualbox" },
    { name: "KVM", icon: "SiKubevirt" },
    { name: "Hyper-V", icon: "SiMicrosoft" },
  ],
  projects: [
    {
      id: "project-1",
      name: "TovPlay Gaming Platform",
      tagline: "Full-Stack Gaming Backend with Real-Time Features",
      description:
        "Production gaming backend built with Flask, PostgreSQL, Socket.IO, and Docker. Features JWT authentication, Discord OAuth integration, real-time multiplayer capabilities, and complete CI/CD pipeline. Handles 1000+ concurrent users with automated testing and deployment workflows.",
      image: "/images/projects/tovplay.svg",
      tech: ["Flask", "PostgreSQL", "Socket.IO", "Docker", "GitHub Actions", "JWT"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/TovPlay",
        app: null,
      },
      featured: true,
    },
    {
      id: "project-2",
      name: "Game Library Manager",
      tagline: "Docker-Based Game Library with Web UI - 928 Games",
      description:
        "Dockerized game library management system with modern web interface. Browse, search, and manage 928 games with detailed metadata, cover art, and download links. Built with JavaScript, Docker, and responsive UI design for seamless navigation.",
      image: "/images/projects/game-library.svg",
      tech: ["Docker", "JavaScript", "Node.js", "Web UI"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/game-library-manager-web",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-3",
      name: "Container Security Scanner",
      tagline: "Automated CVE Detection & CVSS Scoring",
      description:
        "Automated vulnerability scanning tool for Docker images using Trivy. Provides severity reporting with CVSS scores, integrates with CI/CD pipelines for shift-left security, and generates detailed reports for compliance tracking.",
      image: "/images/projects/security-scanner.svg",
      tech: ["Trivy", "Docker", "Python", "GitHub Actions", "Shell"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/container-security-scanner",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-4",
      name: "Prometheus Monitoring Stack",
      tagline: "Full Observability with Grafana & ELK",
      description:
        "Complete monitoring solution with Prometheus metrics collection, custom Grafana dashboards, ELK log aggregation, and PagerDuty alerting. Deployed across multiple production environments with 99.9% uptime SLA.",
      image: "/images/projects/monitoring.svg",
      tech: ["Prometheus", "Grafana", "Elasticsearch", "Docker", "AlertManager"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/prometheus-stack",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-5",
      name: "ArgoCD GitOps Infrastructure",
      tagline: "Kubernetes CD with Automated Rollbacks",
      description:
        "GitOps-based infrastructure with ArgoCD for Kubernetes deployments. Features automated sync, one-click rollback capabilities, Helm chart management, multi-environment support, and Slack notifications for deployment status.",
      image: "/images/projects/argocd.svg",
      tech: ["Kubernetes", "ArgoCD", "Helm", "Terraform", "GitOps"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/argocd-gitops",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-6",
      name: "API Gateway Platform",
      tagline: "High-Performance Request Router & Rate Limiter",
      description:
        "Custom API gateway with intelligent routing, Redis-backed rate limiting, response caching, JWT authentication, and comprehensive request/response logging for microservices architecture.",
      image: "/images/projects/api-gateway.svg",
      tech: ["TypeScript", "Node.js", "Redis", "Docker", "Express"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/api-gateway-platform",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-7",
      name: "Log Analysis AI",
      tagline: "ML-Powered Anomaly Detection",
      description:
        "AI-powered log analysis system with machine learning anomaly detection, pattern recognition, and automated alerting. Integrates with ELK stack for comprehensive observability and reduces MTTR by 60%.",
      image: "/images/projects/log-ai.svg",
      tech: ["Python", "ELK", "scikit-learn", "Docker", "Pandas"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/log-analysis-ai",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-8",
      name: "StartupMaster",
      tagline: "Windows Startup Manager & Optimization Tool",
      description:
        "Advanced C# desktop application for managing Windows startup programs with intelligent optimization suggestions. Features process monitoring, startup delay configuration, registry management, and performance impact analysis to speed up boot times.",
      image: "/images/projects/startupmaster.svg",
      tech: ["C#", ".NET", "WinForms", "Windows API"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/startupmaster",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-9",
      name: "GitDesk",
      tagline: "Desktop Git Client with Visual Interface",
      description:
        "Modern desktop Git client built in C# with WPF. Features branch visualization, commit history graph, merge conflict resolution UI, and integrated diff viewer. Simplifies Git workflows with intuitive visual representations.",
      image: "/images/projects/gitdesk.svg",
      tech: ["C#", "WPF", "Git", ".NET"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/gitdesk",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-10",
      name: "gitit",
      tagline: "Python CLI for Automated Git Workflows",
      description:
        "Command-line automation tool for common Git operations. Streamlines add-commit-push workflows, branch management, and repository maintenance with smart defaults and interactive prompts. Built for speed and efficiency in daily development.",
      image: "/images/projects/gitit.svg",
      tech: ["Python", "CLI", "Git", "Automation"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/gitit",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-11",
      name: "OpenClaw AI Agent",
      tagline: "TypeScript-Powered AI Automation Framework",
      description:
        "Advanced AI agent framework built with TypeScript and Claude API integration. Automates complex workflows, manages multi-session conversations, and provides intelligent task delegation. Features Telegram integration and extensible skill system.",
      image: "/images/projects/openclaw.svg",
      tech: ["TypeScript", "Claude AI", "Node.js", "Telegram API"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/openclaw",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-12",
      name: "YouTube Recommendation Filter",
      tagline: "Browser Extension for Content Control",
      description:
        "JavaScript browser extension that filters YouTube recommendations based on custom rules. Block unwanted content, hide specific channels, and create a cleaner viewing experience with regex pattern matching and whitelist/blacklist management.",
      image: "/images/projects/youtube-filter.svg",
      tech: ["JavaScript", "Browser Extension", "Chrome API"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/youtube_recommendation_filter",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-13",
      name: "TovPlay Frontend",
      tagline: "React Gaming Platform UI with Real-Time Updates",
      description:
        "Modern React frontend for TovPlay gaming platform. Features responsive design, real-time Socket.IO updates, Discord OAuth, JWT authentication, and seamless game library browsing. Built with Vite, Tailwind CSS, and production-ready state management.",
      image: "/images/projects/tovplay-frontend.svg",
      tech: ["React", "Vite", "Tailwind CSS", "Socket.IO", "JWT"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/tovplay-frontend",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-14",
      name: "Job Task Tracker",
      tagline: "Professional Task Management & Documentation System",
      description:
        "Full-stack job documentation and task management application built with modern web technologies. Features task prioritization, time tracking, project organization, team collaboration, and comprehensive reporting for professional workflows.",
      image: "/images/projects/job-tracker.svg",
      tech: ["Node.js", "Express", "PostgreSQL", "React", "Docker"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/job-task-tracker",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-15",
      name: "Windows 11 System Monitor",
      tagline: "Real-Time System Monitoring Dashboard with WebSockets",
      description:
        "Real-time Windows 11 system monitoring dashboard with WebSocket updates. Track CPU, RAM, disk, network usage, running processes, and system health metrics. Built with Node.js, WebSockets, and responsive charting for live visualization.",
      image: "/images/projects/win11-monitor.svg",
      tech: ["Node.js", "WebSockets", "Chart.js", "Windows API", "Express"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/win11-monitor",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-16",
      name: "Claude Reddit Aggregator",
      tagline: "Real-Time AI Discussion Tracker with Dark Mode",
      description:
        "Real-time Reddit aggregator for Claude and AI discussions with dark mode, live updates via Socket.IO, sentiment analysis, and keyword filtering. Fetches posts from multiple subreddits, provides trending topic analysis, and delivers a modern browsing experience.",
      image: "/images/projects/reddit-aggregator.svg",
      tech: ["Node.js", "Reddit API", "Socket.IO", "Express", "JavaScript"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/claude-reddit-aggregator",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-17",
      name: "Claude Code News",
      tagline: "Auto-Updating AI News Aggregator",
      description:
        "Auto-updating news aggregator for Claude Code and Anthropic AI with scheduled fetching, RSS integration, automated content updates, and clean presentation. Stays current with the latest AI developments and Claude ecosystem updates without manual intervention.",
      image: "/images/projects/claude-news.svg",
      tech: ["Node.js", "RSS Parser", "Cron", "Express", "Web Scraping"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/claude-code-news",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-18",
      name: "UninstallPro",
      tagline: "Advanced Windows Application Uninstaller",
      description:
        "Powerful Windows application uninstaller with deep registry cleaning, leftover file detection, forced uninstall capabilities, and bulk removal features. Provides a cleaner alternative to Windows' built-in Programs and Features with comprehensive app management.",
      image: "/images/projects/uninstallpro.svg",
      tech: ["C#", ".NET", "WinForms", "Registry API"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/uninstallpro",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-19",
      name: "Game Launcher Pro",
      tagline: "Unified Gaming Library Manager",
      description:
        "Professional game library manager that consolidates games from multiple platforms. Features automatic game detection, custom categories, favorites, playtime tracking, and a beautiful modern interface for managing your entire gaming collection in one place.",
      image: "/images/projects/game-launcher.svg",
      tech: ["C#", ".NET", "WPF", "SQLite"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/game-launcher-pro",
        app: null,
      },
      featured: false,
    },
    {
      id: "project-20",
      name: "QuadDown",
      tagline: "Multi-Protocol Download Manager",
      description:
        "High-performance download manager supporting HTTP, HTTPS, FTP, and torrents. Features parallel downloading, resume capability, bandwidth control, queue management, and browser integration for seamless downloading experiences.",
      image: "/images/projects/quaddown.svg",
      tech: ["Python", "Qt", "libtorrent", "asyncio"],
      links: {
        website: null,
        source: "https://github.com/Michaelunkai/QuadDown",
        app: null,
      },
      featured: false,
    },
  ],
  templates: [
    {
      name: "Docker CI/CD Starter",
      description:
        "Production-ready CI/CD pipeline template with multi-stage Docker builds, GitHub Actions workflows, automated testing, and one-command deployment.",
      logo: "/images/templates/docker-logo.svg",
      preview: "/images/templates/docker-preview.svg",
      githubUrl: "https://github.com/Michaelunkai/docker-cicd-starter",
    },
    {
      name: "Prometheus Monitoring Kit",
      description:
        "Complete Prometheus + Grafana monitoring setup with pre-configured dashboards for CPU, memory, disk, network, and custom application metrics.",
      logo: "/images/templates/prometheus-logo.svg",
      preview: "/images/templates/prometheus-preview.svg",
      githubUrl: "https://github.com/Michaelunkai/prometheus-monitoring-kit",
    },
    {
      name: "Kubernetes Helm Charts",
      description:
        "Collection of production-ready Helm charts for PostgreSQL, Redis, Nginx, monitoring stack, and common microservices patterns.",
      logo: "/images/templates/k8s-logo.svg",
      preview: "/images/templates/k8s-preview.svg",
      githubUrl: "https://github.com/Michaelunkai/kubernetes-helm-charts",
    },
  ],
  services: [
    {
      id: "devops-consulting",
      name: "DevOps Consulting",
      description:
        "Expert guidance on DevOps transformation, CI/CD implementation, cloud migration strategy, and infrastructure modernization. I'll analyze your current setup and create a roadmap for improvement.",
      icon: "MessageSquare",
      accentColor: "blue",
      price: "$75/hour",
      features: [
        "Infrastructure Assessment & Audit",
        "CI/CD Pipeline Architecture",
        "Cloud Migration Planning",
        "Security & Compliance Review",
        "Team Training & Documentation",
      ],
      popular: false,
    },
    {
      id: "cicd-setup",
      name: "CI/CD Pipeline Setup",
      description:
        "Complete CI/CD pipeline implementation with GitHub Actions or Jenkins. Includes automated testing, Docker builds, deployment automation, and Slack/Discord notifications.",
      icon: "Rocket",
      accentColor: "purple",
      price: "$450",
      features: [
        "GitHub Actions / Jenkins Setup",
        "Multi-stage Docker Builds",
        "Automated Testing Integration",
        "Staging & Production Deploys",
        "Rollback Strategies & Monitoring",
      ],
      popular: true,
    },
    {
      id: "monitoring-stack",
      name: "Monitoring & Alerting",
      description:
        "Full observability stack setup with Prometheus, Grafana, and log aggregation (ELK/Loki). Custom dashboards, smart alerts, on-call integration, and SLA tracking.",
      icon: "Activity",
      accentColor: "green",
      price: "$650",
      features: [
        "Prometheus Metrics Collection",
        "Custom Grafana Dashboards",
        "ELK/Loki Log Aggregation",
        "Smart Alert Rules & PagerDuty",
        "SLA/SLO Monitoring & Reports",
      ],
      popular: false,
    },
    {
      id: "infrastructure-automation",
      name: "Infrastructure Automation",
      description:
        "Infrastructure as Code implementation with Terraform and Ansible. Automate cloud resources, server provisioning, configuration management, and disaster recovery.",
      icon: "Server",
      accentColor: "orange",
      price: "$850",
      features: [
        "Terraform IaC Setup (AWS/Azure/GCP)",
        "Ansible Playbooks & Roles",
        "Multi-Cloud Automation",
        "Kubernetes Deployment Automation",
        "Disaster Recovery & Backup Plans",
      ],
      popular: false,
    },
    {
      id: "automation-scripts",
      name: "Custom Automation Scripts",
      description:
        "Build powerful automation scripts in Python, Bash, or PowerShell to streamline your workflows. From system administration to data processing, I'll create reliable scripts that save you hours daily.",
      icon: "Code2",
      accentColor: "cyan",
      price: "$120",
      features: [
        "Python/Bash/PowerShell Scripts",
        "System Administration Automation",
        "Data Processing & ETL Pipelines",
        "API Integration & Web Scraping",
        "Complete Documentation & Testing",
      ],
      popular: false,
    },
    {
      id: "docker-migration",
      name: "Docker Containerization",
      description:
        "Migrate your applications to Docker containers for consistent, portable deployments. Includes multi-stage builds, docker-compose orchestration, volume management, and container optimization.",
      icon: "Package",
      accentColor: "indigo",
      price: "$380",
      features: [
        "Multi-Stage Dockerfile Optimization",
        "Docker Compose Setup",
        "Volume & Network Configuration",
        "Container Security Hardening",
        "Local Development Environment",
      ],
      popular: false,
    },
    {
      id: "github-actions-workflow",
      name: "GitHub Actions Workflows",
      description:
        "Automate your entire development workflow with custom GitHub Actions. Testing, building, deploying, and notifications - all triggered automatically on git events.",
      icon: "GitBranch",
      accentColor: "yellow",
      price: "$280",
      features: [
        "Custom GitHub Actions Workflows",
        "Automated Testing & Linting",
        "Docker Build & Push to Registry",
        "Environment-Specific Deployments",
        "Slack/Discord Notifications",
      ],
      popular: false,
    },
    {
      id: "linux-server-setup",
      name: "Linux Server Setup & Hardening",
      description:
        "Complete Linux server configuration with security hardening, firewall setup, SSL certificates, automated backups, and monitoring. Perfect for production deployments.",
      icon: "Shield",
      accentColor: "red",
      price: "$420",
      features: [
        "Ubuntu/Debian/CentOS Setup",
        "Security Hardening & Firewall (ufw/iptables)",
        "SSL/TLS Certificate Automation (Let's Encrypt)",
        "Automated Backup Scripts",
        "Basic Monitoring & Log Rotation",
      ],
      popular: false,
    },
    {
      id: "database-optimization",
      name: "Database Performance Tuning",
      description:
        "Optimize PostgreSQL, MySQL, MongoDB, or Redis for maximum performance. Query optimization, indexing strategies, connection pooling, replication setup, and automated backups.",
      icon: "Database",
      accentColor: "teal",
      price: "$340",
      features: [
        "Query Performance Analysis & Optimization",
        "Index Strategy & Database Tuning",
        "Connection Pooling (PgBouncer/ProxySQL)",
        "Master-Slave Replication Setup",
        "Automated Backup & Recovery Plans",
      ],
      popular: false,
    },
    {
      id: "api-development",
      name: "RESTful API Development",
      description:
        "Build production-ready REST APIs with Node.js, Python Flask, or .NET. JWT authentication, rate limiting, API documentation (Swagger/OpenAPI), versioning, and comprehensive testing.",
      icon: "Zap",
      accentColor: "violet",
      price: "$520",
      features: [
        "RESTful API Architecture & Design",
        "JWT/OAuth2 Authentication",
        "Rate Limiting & Caching (Redis)",
        "Swagger/OpenAPI Documentation",
        "Automated Testing (Jest/Pytest)",
      ],
      popular: false,
    },
    {
      id: "kubernetes-migration",
      name: "Kubernetes Migration & Setup",
      description:
        "Migrate your applications to Kubernetes with zero downtime. Helm charts, ingress controllers, auto-scaling, persistent volumes, and multi-environment deployments (dev/staging/prod).",
      icon: "Cloud",
      accentColor: "sky",
      price: "$950",
      features: [
        "Kubernetes Cluster Setup (EKS/GKE/AKS)",
        "Helm Chart Development & Management",
        "Ingress Controllers & Load Balancing",
        "Horizontal Pod Autoscaling",
        "Persistent Storage & StatefulSets",
      ],
      popular: false,
    },
    {
      id: "security-audit",
      name: "Security Audit & Penetration Testing",
      description:
        "Comprehensive security assessment of your infrastructure and applications. Vulnerability scanning (Trivy, OWASP ZAP), penetration testing, compliance checks (GDPR, SOC2), and remediation roadmap.",
      icon: "ShieldCheck",
      accentColor: "rose",
      price: "$680",
      features: [
        "Infrastructure Vulnerability Scanning",
        "Application Security Testing (OWASP)",
        "Container & Docker Security Audit",
        "Compliance Assessment (GDPR/SOC2)",
        "Detailed Remediation Roadmap",
      ],
      popular: false,
    },
    {
      id: "microservices-architecture",
      name: "Microservices Architecture Design",
      description:
        "Design and implement scalable microservices architecture. Service mesh (Istio/Linkerd), API gateways, event-driven patterns, distributed tracing, and inter-service communication strategies.",
      icon: "Network",
      accentColor: "amber",
      price: "$890",
      features: [
        "Microservices Architecture Blueprint",
        "Service Mesh Implementation (Istio)",
        "API Gateway & Load Balancing",
        "Message Queue Integration (Kafka/RabbitMQ)",
        "Distributed Tracing (Jaeger/Zipkin)",
      ],
      popular: false,
    },
    {
      id: "backup-disaster-recovery",
      name: "Backup & Disaster Recovery",
      description:
        "Enterprise-grade backup and disaster recovery solutions. Automated backups (databases, volumes, configs), geo-redundancy, RPO/RTO planning, backup testing, and restoration procedures.",
      icon: "HardDrive",
      accentColor: "emerald",
      price: "$550",
      features: [
        "Automated Backup Scripts (Cron/SystemD)",
        "Multi-Region Geo-Redundancy",
        "RPO/RTO Planning & Documentation",
        "Backup Testing & Validation",
        "One-Click Disaster Recovery Procedures",
      ],
      popular: false,
    },
    {
      id: "log-aggregation",
      name: "Centralized Logging (ELK/Loki)",
      description:
        "Set up centralized logging with Elasticsearch-Logstash-Kibana (ELK) or Grafana Loki. Log parsing, indexing, visualization dashboards, alerting, and long-term log retention strategies.",
      icon: "FileText",
      accentColor: "orange",
      price: "$480",
      features: [
        "ELK Stack / Grafana Loki Setup",
        "Log Parsing & Structured Logging",
        "Custom Kibana/Grafana Dashboards",
        "Log-Based Alerting Rules",
        "Long-Term Retention & Archival",
      ],
      popular: false,
    },
    {
      id: "terraform-migration",
      name: "Infrastructure as Code (Terraform)",
      description:
        "Convert your manual infrastructure to Terraform IaC. State management (S3/remote backend), modules, workspaces, drift detection, and automated apply pipelines with CI/CD integration.",
      icon: "Code",
      accentColor: "purple",
      price: "$720",
      features: [
        "Terraform IaC Conversion & Migration",
        "Remote State Management (S3/Terraform Cloud)",
        "Reusable Modules & Workspaces",
        "Drift Detection & Remediation",
        "CI/CD Integration (GitHub Actions/GitLab)",
      ],
      popular: false,
    },
    {
      id: "chatbot-development",
      name: "AI Chatbot Development",
      description:
        "Build intelligent chatbots with OpenAI, Claude, or open-source LLMs. Telegram, Discord, Slack integration, conversation memory, custom tools, and RAG (Retrieval-Augmented Generation).",
      icon: "MessageCircle",
      accentColor: "pink",
      price: "$650",
      features: [
        "OpenAI/Claude API Integration",
        "Telegram/Discord/Slack Bots",
        "Conversation Context & Memory",
        "Custom Tools & Function Calling",
        "RAG with Vector Databases (Pinecone/Weaviate)",
      ],
      popular: false,
    },
    {
      id: "cost-optimization",
      name: "Cloud Cost Optimization",
      description:
        "Reduce cloud bills by 30-60% without sacrificing performance. Right-sizing, reserved instances, spot instances, idle resource detection, budget alerts, and cost allocation tagging.",
      icon: "DollarSign",
      accentColor: "green",
      price: "$490",
      features: [
        "Cloud Cost Analysis & Audit",
        "Right-Sizing Recommendations",
        "Reserved/Spot Instance Planning",
        "Idle Resource Detection & Cleanup",
        "Budget Alerts & Cost Allocation Tags",
      ],
      popular: false,
    },
    {
      id: "web-scraping",
      name: "Web Scraping & Automation",
      description:
        "Build robust web scrapers with Puppeteer, Playwright, or Scrapy. Anti-bot bypass, headless browsers, data extraction pipelines, scheduling, proxy rotation, and data storage (PostgreSQL/MongoDB).",
      icon: "Globe",
      accentColor: "blue",
      price: "$380",
      features: [
        "Puppeteer/Playwright/Scrapy Scrapers",
        "Anti-Bot Detection Bypass",
        "Headless Browser Automation",
        "Proxy Rotation & IP Management",
        "Data Pipeline & Storage (PostgreSQL/MongoDB)",
      ],
      popular: false,
    },
  ],
  process: [
    {
      step: 1,
      name: "Discovery",
      description:
        "Deep dive into your infrastructure, tech stack, pain points, and business goals. I audit your systems and identify improvement opportunities.",
      icon: "MessageSquare",
      gradient: "from-blue-500 to-cyan-500",
    },
    {
      step: 2,
      name: "Architecture",
      description:
        "Design a tailored solution with technical specifications, technology choices, implementation roadmap, and cost estimates aligned with your budget.",
      icon: "Code2",
      gradient: "from-purple-500 to-pink-500",
    },
    {
      step: 3,
      name: "Implementation",
      description:
        "Build your infrastructure using best practices: Infrastructure as Code, containerization, CI/CD automation, security hardening, and monitoring.",
      icon: "Server",
      gradient: "from-orange-500 to-red-500",
    },
    {
      step: 4,
      name: "Handoff",
      description:
        "Complete documentation, team training, knowledge transfer, and post-launch support. Your team will be confident to maintain and extend the infrastructure.",
      icon: "Rocket",
      gradient: "from-green-500 to-emerald-500",
    },
  ],
};

export type Portfolio = typeof portfolio;
export type Project = (typeof portfolio.projects)[number];
export type Template = (typeof portfolio.templates)[number];
export type Service = (typeof portfolio.services)[number];
export type ProcessStep = (typeof portfolio.process)[number];
export type TechItem = (typeof portfolio.techStack)[number];
export type Stat = (typeof portfolio.stats)[number];
export type Resume = (typeof portfolio.resumes)[number];
