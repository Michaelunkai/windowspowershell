"use client";

import { motion } from "framer-motion";
import { Cloud, Container, Activity, Shield, Database, Code2, GitBranch, Server, Network, Lock, Zap, FileText, HardDrive, DollarSign, Globe, Cpu } from "lucide-react";
import { fadeUpFast } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";
import TechBadge from "@/components/ui/TechBadge";

const focusAreas = [
  {
    icon: Cloud,
    title: "Cloud Infrastructure",
    description:
      "Architecting scalable, cost-optimized cloud solutions on AWS, Azure, and GCP. VPC design, auto-scaling groups, serverless architectures, and multi-region deployments.",
    color: "from-blue-500 to-cyan-500",
  },
  {
    icon: Container,
    title: "Container Orchestration",
    description:
      "Docker containerization, Kubernetes deployments, Helm chart management, and ArgoCD GitOps workflows. Building production-grade microservices architectures.",
    color: "from-cyan-500 to-teal-500",
  },
  {
    icon: Activity,
    title: "CI/CD & Automation",
    description:
      "Building robust pipelines with GitHub Actions, Jenkins, and GitLab CI. Infrastructure as Code with Terraform and Ansible for automated, repeatable deployments.",
    color: "from-purple-500 to-pink-500",
  },
  {
    icon: Shield,
    title: "Monitoring & Security",
    description:
      "Full observability stacks with Prometheus, Grafana, and ELK. Container scanning with Trivy, vulnerability management, compliance automation, and incident response.",
    color: "from-orange-500 to-red-500",
  },
  {
    icon: Database,
    title: "Database Management",
    description:
      "PostgreSQL, MySQL, MongoDB, Redis optimization. Query tuning, indexing strategies, replication, sharding, connection pooling, and automated backup solutions.",
    color: "from-green-500 to-emerald-500",
  },
  {
    icon: Code2,
    title: "Scripting & Automation",
    description:
      "Python, Bash, PowerShell automation scripts. System administration, data processing, ETL pipelines, API integrations, and scheduled task automation.",
    color: "from-violet-500 to-purple-500",
  },
  {
    icon: GitBranch,
    title: "Version Control & GitOps",
    description:
      "Git workflows, branching strategies, ArgoCD, FluxCD. GitOps principles, automated deployments, rollback strategies, and collaborative development practices.",
    color: "from-pink-500 to-rose-500",
  },
  {
    icon: Server,
    title: "Linux System Administration",
    description:
      "Ubuntu, Debian, CentOS, RHEL administration. Security hardening, performance tuning, systemd services, kernel optimization, and production server management.",
    color: "from-amber-500 to-orange-500",
  },
  {
    icon: Network,
    title: "Networking & Load Balancing",
    description:
      "Nginx, HAProxy, Traefik configuration. DNS management, SSL/TLS certificates, reverse proxies, CDN integration (Cloudflare), and traffic distribution.",
    color: "from-teal-500 to-cyan-500",
  },
  {
    icon: Lock,
    title: "Security & Compliance",
    description:
      "OWASP security best practices, penetration testing, vulnerability scanning. GDPR, SOC2 compliance, secrets management (Vault), and security audits.",
    color: "from-red-500 to-rose-500",
  },
  {
    icon: Zap,
    title: "API Development",
    description:
      "RESTful APIs with Node.js, Python Flask, .NET. JWT authentication, rate limiting, API documentation (Swagger/OpenAPI), versioning, and comprehensive testing.",
    color: "from-yellow-500 to-amber-500",
  },
  {
    icon: FileText,
    title: "Log Aggregation",
    description:
      "ELK Stack (Elasticsearch, Logstash, Kibana), Grafana Loki. Centralized logging, log parsing, structured logging, custom dashboards, and alerting.",
    color: "from-indigo-500 to-blue-500",
  },
  {
    icon: HardDrive,
    title: "Backup & Disaster Recovery",
    description:
      "Automated backup strategies, geo-redundancy, RPO/RTO planning. Backup testing, validation, restoration procedures, and business continuity planning.",
    color: "from-slate-500 to-gray-500",
  },
  {
    icon: DollarSign,
    title: "Cost Optimization",
    description:
      "Cloud cost analysis, right-sizing, reserved/spot instances. Idle resource detection, budget alerts, cost allocation tagging, and 30-60% cost reduction strategies.",
    color: "from-green-500 to-teal-500",
  },
  {
    icon: Globe,
    title: "Web Scraping & Data Extraction",
    description:
      "Puppeteer, Playwright, Scrapy development. Anti-bot bypass, headless browser automation, proxy rotation, data pipelines, and storage integration.",
    color: "from-blue-500 to-indigo-500",
  },
  {
    icon: Cpu,
    title: "Performance Optimization",
    description:
      "Application profiling, bottleneck identification, caching strategies (Redis, Memcached). Query optimization, CDN integration, and scalability improvements.",
    color: "from-purple-500 to-pink-500",
  },
];

export default function FocusSection() {
  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {/* Section Title */}
        <motion.div
          {...fadeUpFast}
          className="text-center mb-12"
        >
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            What I Do
          </h2>
          <p className="text-gray-400 max-w-2xl mx-auto">
            Specializing in modern DevOps practices and infrastructure automation
            to help organizations scale efficiently and reliably.
          </p>
        </motion.div>

        {/* Focus Cards - Grid with instant visibility */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          {focusAreas.map((area, index) => (
            <motion.div
              key={area.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, amount: 0.2, margin: "0px 0px -50px 0px" }}
              transition={{ duration: 0.3, delay: index * 0.05 }}
              className="group relative p-6 bg-gradient-to-br from-[#0f1020] to-[#141528] rounded-2xl border border-white/[0.07] hover:border-cyan-500/50 transition-all hover:-translate-y-2 overflow-hidden"
            >
              {/* Gradient overlay */}
              <div className={`absolute inset-0 bg-gradient-to-br ${area.color} opacity-0 group-hover:opacity-10 transition-opacity`} />
              
              {/* Icon with glow */}
              <div className="relative mb-4">
                <div className={`absolute inset-0 bg-gradient-to-br ${area.color} blur-xl opacity-0 group-hover:opacity-50 transition-opacity`} />
                <area.icon className="relative w-12 h-12 text-cyan-400 group-hover:scale-110 transition-transform" />
              </div>

              <h3 className="relative text-xl font-semibold text-white mb-3">
                {area.title}
              </h3>
              <p className="relative text-gray-400 text-sm leading-relaxed">{area.description}</p>
            </motion.div>
          ))}
        </div>

        {/* Tech Stack */}
        <motion.div
          {...fadeUpFast}
          className="text-center"
        >
          <h3 className="text-xl font-semibold text-white mb-6">
            Technologies I Work With
          </h3>
          <div className="flex flex-wrap justify-center gap-3">
            {portfolio.techStack.map((tech) => (
              <TechBadge key={tech.name} name={tech.name} icon={tech.icon} />
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
