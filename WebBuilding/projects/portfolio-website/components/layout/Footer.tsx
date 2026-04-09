"use client";

import Link from "next/link";
import { Github, Linkedin, Mail, Phone, MapPin, Heart } from "lucide-react";
import { portfolio } from "@/data/portfolio";
import ContactForm from "@/components/services/ContactForm";

export default function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-[#0a0b14] border-t border-white/[0.05]">
      {/* Contact Form Section */}
      <ContactForm />
      
      {/* Footer Info */}
      <div className="py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
          {/* About Column */}
          <div>
            <h3 className="text-lg font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent mb-4">
              MichaelDev
            </h3>
            <p className="text-gray-400 text-sm mb-4">
              DevOps Engineer specializing in cloud infrastructure automation,
              CI/CD pipelines, and production-grade monitoring systems.
            </p>
            <div className="flex items-center gap-3">
              <Link
                href={portfolio.socials.github}
                target="_blank"
                rel="noopener noreferrer"
                className="p-2 rounded-lg bg-white/5 text-gray-400 hover:text-cyan-400 hover:bg-white/10 transition-all"
                aria-label="Visit Michael's GitHub Profile"
              >
                <Github className="w-5 h-5" />
              </Link>
              <Link
                href={portfolio.socials.linkedin}
                target="_blank"
                rel="noopener noreferrer"
                className="p-2 rounded-lg bg-white/5 text-gray-400 hover:text-cyan-400 hover:bg-white/10 transition-all"
                aria-label="Visit Michael's LinkedIn Profile"
              >
                <Linkedin className="w-5 h-5" />
              </Link>
            </div>
          </div>

          {/* Quick Links Column */}
          <div>
            <h3 className="text-lg font-semibold text-white mb-4">Quick Links</h3>
            <ul className="space-y-2">
              <li>
                <Link
                  href="/"
                  className="text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  Home
                </Link>
              </li>
              <li>
                <Link
                  href="/#projects"
                  className="text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  Projects
                </Link>
              </li>
              <li>
                <Link
                  href="/#about"
                  className="text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  About
                </Link>
              </li>
              <li>
                <Link
                  href="/services"
                  className="text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  Services
                </Link>
              </li>
              <li>
                <Link
                  href="/services#contact"
                  className="text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  Contact
                </Link>
              </li>
            </ul>
          </div>

          {/* Contact Column */}
          <div>
            <h3 className="text-lg font-semibold text-white mb-4">Contact</h3>
            <ul className="space-y-3">
              <li>
                <a
                  href={`mailto:${portfolio.personal.email}`}
                  className="flex items-center gap-2 text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  <Mail className="w-4 h-4 text-cyan-400" />
                  {portfolio.personal.email}
                </a>
              </li>
              <li>
                <a
                  href={`tel:${portfolio.personal.phone}`}
                  className="flex items-center gap-2 text-gray-400 hover:text-cyan-400 transition-colors text-sm"
                >
                  <Phone className="w-4 h-4 text-cyan-400" />
                  {portfolio.personal.phone}
                </a>
              </li>
              <li className="flex items-center gap-2 text-gray-400 text-sm">
                <MapPin className="w-4 h-4 text-cyan-400" />
                {portfolio.personal.location}
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="pt-8 border-t border-white/[0.05] flex flex-col md:flex-row items-center justify-between gap-4 text-sm text-gray-400">
          <p>
            © {currentYear} Michael Fedorovsky. All rights reserved.
          </p>
          <p className="flex items-center gap-1">
            Built with <Heart className="w-4 h-4 text-red-500 fill-red-500" /> by Michael Fedorovsky
          </p>
        </div>
      </div>
      </div>
    </footer>
  );
}
