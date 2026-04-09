"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { ChevronDown, ChevronUp, Award, Briefcase, Code, Database, Shield, Zap, Server, GitBranch, FileText, Globe, Lock, Cpu } from "lucide-react";
import { fadeUpFast, expandHeight } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";

const skillCategories = [
  {
    category: "Cloud & Infrastructure",
    skills: ["AWS", "Azure", "Docker", "Kubernetes", "Terraform"],
    icon: Code,
  },
  {
    category: "CI/CD & Automation",
    skills: ["GitHub Actions", "Jenkins", "Ansible", "ArgoCD"],
    icon: Briefcase,
  },
  {
    category: "Monitoring & Security",
    skills: ["Prometheus", "Grafana", "ELK Stack", "Trivy", "Vault"],
    icon: Award,
  },
  {
    category: "Database Management",
    skills: ["PostgreSQL", "MySQL", "MongoDB", "Redis", "Replication"],
    icon: Database,
  },
  {
    category: "Security & Compliance",
    skills: ["OWASP", "Penetration Testing", "GDPR", "SOC2", "Vault"],
    icon: Shield,
  },
  {
    category: "API Development",
    skills: ["REST APIs", "Node.js", "Flask", ".NET", "JWT Auth"],
    icon: Zap,
  },
  {
    category: "Linux Administration",
    skills: ["Ubuntu", "CentOS", "RHEL", "Systemd", "Security Hardening"],
    icon: Server,
  },
  {
    category: "Version Control & GitOps",
    skills: ["Git", "GitHub", "GitLab", "ArgoCD", "FluxCD"],
    icon: GitBranch,
  },
  {
    category: "Log Aggregation",
    skills: ["Elasticsearch", "Logstash", "Kibana", "Grafana Loki", "Fluentd"],
    icon: FileText,
  },
  {
    category: "Networking & CDN",
    skills: ["Nginx", "HAProxy", "Cloudflare", "DNS", "SSL/TLS"],
    icon: Globe,
  },
  {
    category: "Secrets Management",
    skills: ["HashiCorp Vault", "AWS Secrets Manager", "Environment Vars", "Encryption"],
    icon: Lock,
  },
  {
    category: "Performance Optimization",
    skills: ["Caching (Redis)", "CDN", "Query Optimization", "Load Balancing", "Profiling"],
    icon: Cpu,
  },
  {
    category: "Scripting & Development",
    skills: ["Python", "Bash", "PowerShell", "TypeScript", "C#"],
    icon: Code,
  },
];

const timeline = [
  {
    year: "2023 - Present",
    role: "Senior DevOps Engineer & Cloud Architect",
    company: "TovTech",
    achievements: [
      "Architected and deployed multi-environment cloud infrastructure (production, staging, development) on AWS and Webdock with Cloudflare CDN integration, serving 10,000+ daily active users",
      "Built comprehensive CI/CD pipelines with GitHub Actions achieving 60% faster deployment times, 80% reduction in deployment failures, and zero-downtime releases",
      "Deployed full observability stack (Prometheus, Grafana, ELK) achieving 99.9% uptime SLA, reducing MTTR by 70%, and enabling real-time incident response",
      "Designed and managed high-availability PostgreSQL clusters with automated backups, point-in-time recovery, master-slave replication, and connection pooling (PgBouncer) handling 50,000+ queries/hour",
      "Implemented comprehensive security practices: container vulnerability scanning with Trivy, automated certificate management (Let's Encrypt), firewall hardening (ufw/iptables), secrets management with HashiCorp Vault, and compliance controls (GDPR, SOC2)",
      "Led infrastructure cost optimization initiatives reducing monthly cloud spend by 40% through right-sizing, reserved instances, auto-scaling policies, and idle resource detection",
      "Developed custom monitoring dashboards providing real-time visibility into application performance, infrastructure health, security events, and business metrics",
      "Automated infrastructure provisioning with Terraform (IaC) and Ansible configuration management, enabling consistent, repeatable deployments across all environments",
      "Implemented GitOps workflows with ArgoCD for Kubernetes deployments, achieving automated sync, one-click rollbacks, and audit trails for all infrastructure changes",
      "Built automated testing pipelines integrating unit tests, integration tests, security scans, and performance benchmarks into CI/CD workflows",
    ],
  },
  {
    year: "2022 - 2023",
    role: "DevOps Engineer & System Administrator",
    company: "Freelance / Open Source Contributor",
    achievements: [
      "Developed 50+ production-grade automation tools and scripts (Python, Bash, PowerShell) streamlining system administration tasks, reducing manual work by 75%, and improving operational efficiency",
      "Created enterprise-ready container security scanner integrating Trivy for CVE detection, CVSS scoring, automated reporting, and CI/CD pipeline integration",
      "Built high-performance API gateway platform with intelligent routing, Redis-backed rate limiting (10,000 req/min), response caching, JWT authentication, and comprehensive request/response logging",
      "Designed and deployed Kubernetes clusters with Helm chart management, horizontal pod autoscaling, persistent storage (PVs/PVCs), ingress controllers (Nginx/Traefik), and service mesh (Istio)",
      "Implemented Infrastructure as Code (Terraform) for AWS, Azure, and GCP resources with remote state management, workspaces, modules, and drift detection",
      "Contributed to multiple high-impact open-source DevOps projects, submitting 30+ pull requests, fixing critical bugs, and improving documentation",
      "Built web scraping pipelines with Puppeteer/Playwright handling anti-bot detection, proxy rotation, headless browser automation, and data storage (PostgreSQL/MongoDB)",
      "Developed AI chatbots with OpenAI/Claude API integration featuring conversation memory, custom tools, RAG (Retrieval-Augmented Generation), and multi-platform support (Telegram, Discord, Slack)",
      "Created real-time monitoring dashboards with WebSocket updates, custom visualizations (Chart.js/D3.js), alerting rules, and integration with Slack/PagerDuty for incident management",
      "Architected microservices-based applications with Docker, Kubernetes orchestration, API gateways, message queues (RabbitMQ/Kafka), and distributed tracing (Jaeger)",
    ],
  },
  {
    year: "2021 - 2022",
    role: "Junior DevOps Engineer & IT Specialist",
    company: "Self-Directed Learning & Personal Projects",
    achievements: [
      "Mastered cloud platforms (AWS, Azure, GCP) through hands-on labs, certifications prep, and real-world project implementations",
      "Built comprehensive home lab environment with virtualization (VMware, VirtualBox), containerization (Docker), and Kubernetes mini-clusters for continuous learning",
      "Developed Windows desktop applications in C#/.NET including system optimization tools, startup managers, application uninstallers, and Git workflow utilities",
      "Created automation scripts for system administration tasks: backup automation, log rotation, disk cleanup, service management, and scheduled maintenance",
      "Learned and implemented networking fundamentals: TCP/IP, DNS, DHCP, VPNs, firewalls, load balancing, and reverse proxies",
      "Studied database administration: PostgreSQL/MySQL optimization, query tuning, indexing strategies, backup/restore procedures, and replication setup",
      "Practiced security best practices: vulnerability scanning, penetration testing basics, encryption, secure coding, OWASP Top 10, and compliance frameworks",
      "Built personal portfolio projects showcasing full-stack development, DevOps automation, cloud deployment, and infrastructure management skills",
    ],
  },
];

export default function AboutSection() {
  const [showJourney, setShowJourney] = useState(false);

  return (
    <section id="about" className="py-20 px-4 sm:px-6 lg:px-8 bg-[#0a0b14]">
      <div className="max-w-5xl mx-auto">
        {/* Title */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.1 }}
          transition={{ duration: 0.3, ease: [0.25, 0.1, 0.25, 1] }}
          className="text-center mb-12"
        >
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            About Me
          </h2>
          <p className="text-gray-300 max-w-4xl mx-auto text-lg leading-relaxed mb-6">
            I'm a <span className="text-cyan-400 font-semibold">DevOps Engineer</span> with 3+ years of hands-on experience building and maintaining production infrastructure that powers real businesses. My journey started with a deep fascination for system automation and grew into a comprehensive skill set spanning <span className="text-cyan-400">cloud architecture, container orchestration, CI/CD pipelines, and security automation</span>.
          </p>
          <p className="text-gray-400 max-w-4xl mx-auto leading-relaxed mb-6">
            At <span className="text-white font-medium">TovTech</span>, I designed and deployed multi-environment cloud infrastructure on AWS and Webdock with Cloudflare CDN integration, achieving <span className="text-green-400 font-semibold">99.9% uptime</span> and <span className="text-green-400 font-semibold">60% faster deployment times</span>. I built comprehensive CI/CD pipelines with GitHub Actions, automated testing workflows, Docker multi-stage builds, and zero-downtime deployments. My monitoring stack (Prometheus + Grafana + ELK) provides real-time visibility into system health, application performance, and security events.
          </p>
          <p className="text-gray-400 max-w-4xl mx-auto leading-relaxed mb-6">
            I've developed <span className="text-cyan-400 font-semibold">50+ production-grade automation tools</span> ranging from container security scanners (Trivy integration) to API gateways with rate limiting and caching. My expertise spans <span className="text-white">Python, Bash, PowerShell scripting</span> for system administration, <span className="text-white">Infrastructure as Code (Terraform/Ansible)</span>, <span className="text-white">Kubernetes orchestration with Helm and ArgoCD</span>, and <span className="text-white">database management (PostgreSQL, MongoDB, Redis)</span> with replication and automated backups.
          </p>
          <p className="text-gray-400 max-w-4xl mx-auto leading-relaxed mb-6">
            Security is at the core of everything I build. I implement <span className="text-red-400">OWASP best practices</span>, conduct vulnerability scanning with Trivy, manage secrets with HashiCorp Vault, enforce compliance (GDPR, SOC2), and perform regular security audits. My infrastructure follows the principle of least privilege, automated certificate management (Let's Encrypt), firewall hardening (ufw/iptables), and comprehensive logging for incident response.
          </p>
          <p className="text-gray-400 max-w-4xl mx-auto leading-relaxed mb-6">
            Beyond technical skills, I excel at <span className="text-purple-400">cost optimization</span>—reducing cloud bills by 30-60% through right-sizing, reserved/spot instances, and idle resource detection. I've built <span className="text-blue-400">web scraping pipelines</span> with Puppeteer/Playwright, <span className="text-yellow-400">AI chatbots</span> with OpenAI/Claude integration, and <span className="text-pink-400">real-time monitoring dashboards</span> with WebSocket updates. My work combines DevOps best practices with modern development techniques to deliver scalable, maintainable, and cost-effective solutions.
          </p>
          <p className="text-gray-300 max-w-4xl mx-auto leading-relaxed text-lg">
            I'm passionate about <span className="text-cyan-400 font-semibold">solving complex infrastructure challenges</span>, automating repetitive tasks, and empowering development teams with robust, reliable systems. Whether you need cloud migration, CI/CD implementation, Kubernetes orchestration, or security hardening—I deliver production-ready solutions that scale with your business.
          </p>
        </motion.div>

        {/* Skills Grid */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.1 }}
          transition={{ duration: 0.3, ease: [0.25, 0.1, 0.25, 1] }}
          className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12"
        >
          {skillCategories.map((cat) => (
            <div
              key={cat.category}
              className="bg-gradient-to-br from-[#0f1020] to-[#141528] rounded-xl border border-cyan-500/20 p-6 hover:border-cyan-500/50 transition-all"
            >
              <cat.icon className="w-8 h-8 text-cyan-400 mb-3" />
              <h3 className="text-lg font-semibold text-white mb-3">
                {cat.category}
              </h3>
              <div className="flex flex-wrap gap-2">
                {cat.skills.map((skill) => (
                  <span
                    key={skill}
                    className="px-3 py-1 bg-cyan-500/10 text-cyan-400 text-sm rounded-full border border-cyan-500/20"
                  >
                    {skill}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </motion.div>

        {/* Journey Toggle */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.1 }}
          transition={{ duration: 0.3, ease: [0.25, 0.1, 0.25, 1] }}
          className="text-center mb-8"
        >
          <button
            onClick={() => setShowJourney(!showJourney)}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-cyan-500/20 to-blue-500/20 border border-cyan-500/30 text-cyan-400 rounded-xl font-medium hover:bg-cyan-500/30 transition-all"
          >
            {showJourney ? (
              <>
                Hide Career Timeline
                <ChevronUp className="w-4 h-4" />
              </>
            ) : (
              <>
                View Career Timeline
                <ChevronDown className="w-4 h-4" />
              </>
            )}
          </button>
        </motion.div>

        {/* Timeline */}
        <AnimatePresence>
          {showJourney && (
            <motion.div
              {...expandHeight}
              className="overflow-hidden"
            >
              <div className="space-y-8 pt-8">
                {timeline.map((item, index) => (
                  <div
                    key={index}
                    className="relative pl-8 border-l-2 border-cyan-500/30"
                  >
                    {/* Timeline dot */}
                    <div className="absolute -left-[9px] top-0 w-4 h-4 rounded-full bg-cyan-500 border-4 border-[#0a0b14]" />
                    
                    <div className="bg-gradient-to-br from-[#0f1020] to-[#141528] rounded-xl border border-white/[0.07] p-6">
                      <div className="text-sm text-cyan-400 font-medium mb-1">
                        {item.year}
                      </div>
                      <h3 className="text-xl font-bold text-white mb-1">
                        {item.role}
                      </h3>
                      <div className="text-gray-400 mb-4">{item.company}</div>
                      <ul className="space-y-2">
                        {item.achievements.map((achievement, i) => (
                          <li key={i} className="text-sm text-gray-400 flex items-start gap-2">
                            <span className="text-cyan-400 mt-1">•</span>
                            <span>{achievement}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  </div>
                ))}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </section>
  );
}
