"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import { Send, CheckCircle, AlertCircle, Loader2 } from "lucide-react";

interface FormData {
  name: string;
  email: string;
  phone: string;
  projectType: string;
  budget: string;
  timeline: string;
  details: string;
  consent: boolean;
}

type FormStatus = "idle" | "loading" | "success" | "error";

export default function ContactForm() {
  const [formData, setFormData] = useState<FormData>({
    name: "",
    email: "",
    phone: "",
    projectType: "",
    budget: "",
    timeline: "",
    details: "",
    consent: false,
  });

  const [status, setStatus] = useState<FormStatus>("idle");
  const [message, setMessage] = useState("");

  const handleChange = (
    e: React.ChangeEvent<
      HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement
    >
  ) => {
    const { name, value, type } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]:
        type === "checkbox" ? (e.target as HTMLInputElement).checked : value,
    }));
  };

  const validateForm = (): boolean => {
    if (!formData.name.trim()) {
      setMessage("Please enter your name");
      return false;
    }
    if (!formData.email.trim() || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      setMessage("Please enter a valid email address");
      return false;
    }
    if (!formData.projectType) {
      setMessage("Please select a project type");
      return false;
    }
    if (!formData.details.trim()) {
      setMessage("Please provide project details");
      return false;
    }
    if (!formData.consent) {
      setMessage("Please agree to be contacted");
      return false;
    }
    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setMessage("");

    if (!validateForm()) {
      setStatus("error");
      return;
    }

    setStatus("loading");

    try {
      const response = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(formData),
      });

      const data = await response.json();

      if (response.ok) {
        setStatus("success");
        setMessage("Message sent successfully! I'll get back to you soon.");
        setFormData({
          name: "",
          email: "",
          phone: "",
          projectType: "",
          budget: "",
          timeline: "",
          details: "",
          consent: false,
        });
      } else {
        setStatus("error");
        setMessage(data.error || "Failed to send message. Please try again.");
      }
    } catch (error) {
      setStatus("error");
      setMessage("Network error. Please try again later.");
    }
  };

  return (
    <section id="contact" className="py-20 px-4 sm:px-6 lg:px-8 bg-[#0a0b14]">
      <div className="max-w-3xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.4 }}
          className="text-center mb-12"
        >
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            Get In Touch
          </h2>
          <p className="text-gray-400">
            Ready to build something great? Let's discuss your project.
          </p>
        </motion.div>

        <motion.form
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 0.4, delay: 0.1 }}
          onSubmit={handleSubmit}
          className="bg-gradient-to-br from-[#0f1020] to-[#141528] rounded-2xl border border-white/[0.07] p-8"
        >
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div>
              <label htmlFor="name" className="block text-sm font-medium text-gray-300 mb-2">
                Name *
              </label>
              <input
                type="text"
                id="name"
                name="name"
                value={formData.name}
                onChange={handleChange}
                className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500 transition-colors"
                placeholder="Your name"
                required
              />
            </div>

            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-300 mb-2">
                Email *
              </label>
              <input
                type="email"
                id="email"
                name="email"
                value={formData.email}
                onChange={handleChange}
                className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500 transition-colors"
                placeholder="your.email@example.com"
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div>
              <label htmlFor="phone" className="block text-sm font-medium text-gray-300 mb-2">
                Phone / WhatsApp (Optional)
              </label>
              <input
                type="tel"
                id="phone"
                name="phone"
                value={formData.phone}
                onChange={handleChange}
                className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500 transition-colors"
                placeholder="+1 234 567 8900"
              />
            </div>

            <div>
              <label htmlFor="projectType" className="block text-sm font-medium text-gray-300 mb-2">
                Project Type *
              </label>
              <select
                id="projectType"
                name="projectType"
                value={formData.projectType}
                onChange={handleChange}
                className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white focus:outline-none focus:border-cyan-500 transition-colors"
                required
              >
                <option value="">Select a service</option>
                <option value="consulting">DevOps Consulting</option>
                <option value="cicd">CI/CD Pipeline Setup</option>
                <option value="monitoring">Monitoring & Alerting</option>
                <option value="infrastructure">Infrastructure Automation</option>
                <option value="automation-scripts">Custom Automation Scripts</option>
                <option value="docker">Docker Containerization</option>
                <option value="github-actions">GitHub Actions Workflows</option>
                <option value="linux-server">Linux Server Setup & Hardening</option>
                <option value="database">Database Performance Tuning</option>
                <option value="api-development">RESTful API Development</option>
                <option value="kubernetes">Kubernetes Migration & Setup</option>
                <option value="security-audit">Security Audit & Penetration Testing</option>
                <option value="microservices">Microservices Architecture Design</option>
                <option value="backup-recovery">Backup & Disaster Recovery</option>
                <option value="log-aggregation">Centralized Logging (ELK/Loki)</option>
                <option value="terraform">Infrastructure as Code (Terraform)</option>
                <option value="chatbot">AI Chatbot Development</option>
                <option value="cost-optimization">Cloud Cost Optimization</option>
                <option value="web-scraping">Web Scraping & Automation</option>
                <option value="full-stack">Full-Stack Development</option>
                <option value="other">Other</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div>
              <label htmlFor="budget" className="block text-sm font-medium text-gray-300 mb-2">
                Budget Range (Optional)
              </label>
              <select
                id="budget"
                name="budget"
                value={formData.budget}
                onChange={handleChange}
                className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white focus:outline-none focus:border-cyan-500 transition-colors"
              >
                <option value="">Select budget range</option>
                <option value="under-200">Under $200</option>
                <option value="200-500">$200 - $500</option>
                <option value="500-1000">$500 - $1,000</option>
                <option value="1000-2000">$1,000 - $2,000</option>
                <option value="2000-3000">$2,000 - $3,000</option>
                <option value="3000-5000">$3,000 - $5,000</option>
                <option value="5000-10000">$5,000 - $10,000</option>
                <option value="10000-plus">$10,000+</option>
                <option value="hourly">Hourly Rate ($50-$150/hr)</option>
                <option value="flexible">Flexible / Negotiable</option>
              </select>
            </div>

            <div>
              <label htmlFor="timeline" className="block text-sm font-medium text-gray-300 mb-2">
                Timeline (Optional)
              </label>
              <select
                id="timeline"
                name="timeline"
                value={formData.timeline}
                onChange={handleChange}
                className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white focus:outline-none focus:border-cyan-500 transition-colors"
              >
                <option value="">Select timeline</option>
                <option value="urgent">ASAP (1-2 weeks)</option>
                <option value="normal">Normal (1 month)</option>
                <option value="flexible">Flexible (2+ months)</option>
              </select>
            </div>
          </div>

          <div className="mb-6">
            <label htmlFor="details" className="block text-sm font-medium text-gray-300 mb-2">
              Project Details *
            </label>
            <textarea
              id="details"
              name="details"
              value={formData.details}
              onChange={handleChange}
              rows={5}
              className="w-full px-4 py-3 bg-[#0a0b14] border border-white/10 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-cyan-500 transition-colors resize-none"
              placeholder="Tell me about your project, infrastructure, and what you need help with..."
              required
            />
          </div>

          <div className="mb-6">
            <label className="flex items-start gap-2 cursor-pointer">
              <input
                type="checkbox"
                name="consent"
                checked={formData.consent}
                onChange={handleChange}
                className="mt-1 w-4 h-4 rounded border-white/10 bg-[#0a0b14] text-cyan-500 focus:ring-cyan-500 focus:ring-offset-0"
                required
              />
              <span className="text-sm text-gray-400">
                I agree to be contacted via Email or WhatsApp about this project. *
              </span>
            </label>
          </div>

          {message && (
            <div
              className={`mb-6 p-4 rounded-lg flex items-center gap-2 ${
                status === "success"
                  ? "bg-green-500/20 border border-green-500/30 text-green-400"
                  : "bg-red-500/20 border border-red-500/30 text-red-400"
              }`}
            >
              {status === "success" ? (
                <CheckCircle className="w-5 h-5" />
              ) : (
                <AlertCircle className="w-5 h-5" />
              )}
              <span className="text-sm">{message}</span>
            </div>
          )}

          <button
            type="submit"
            disabled={status === "loading"}
            className="w-full px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 text-white rounded-xl font-medium hover:shadow-[0_0_30px_rgba(6,182,212,0.5)] transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 group"
          >
            {status === "loading" ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                Sending...
              </>
            ) : (
              <>
                Send Message
                <Send className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </>
            )}
          </button>
        </motion.form>
      </div>
    </section>
  );
}
