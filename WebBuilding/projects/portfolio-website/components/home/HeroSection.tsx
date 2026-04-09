"use client";

import { motion } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import { ArrowRight, MapPin, Mail, Phone, Github, Linkedin } from "lucide-react";
import { portfolio } from "@/data/portfolio";
import { useEffect, useState } from "react";

const typedTexts = [
  "DevOps Engineer",
  "System Administrator", 
  "AI Automation Specialist",
  "Cloud Architect"
];

export default function HeroSection() {
  const [typedIndex, setTypedIndex] = useState(0);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    setIsVisible(true);
    const interval = setInterval(() => {
      setTypedIndex((prev) => (prev + 1) % typedTexts.length);
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <section className="min-h-[90vh] flex flex-col items-center justify-center px-4 sm:px-6 lg:px-8 py-20">
      <div className="max-w-6xl mx-auto w-full">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          {/* Left side - Content */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: isVisible ? 1 : 0 }}
            transition={{ duration: 0.4 }}
            className="text-center lg:text-left"
          >
            {/* Badge */}
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-green-500/20 border border-green-500/40 mb-6 animate-pulse">
              <div className="w-2 h-2 rounded-full bg-green-500" />
              <span className="text-sm text-green-400 font-medium">
                Open to new opportunities
              </span>
            </div>

            {/* Name */}
            <h1 className="text-4xl sm:text-5xl md:text-6xl font-bold text-white mb-2">
              {portfolio.personal.name}
            </h1>

            {/* Typed Title */}
            <div className="h-12 mb-4">
              <motion.h2
                key={typedIndex}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.3 }}
                className="text-xl sm:text-2xl md:text-3xl bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent font-bold"
              >
                {typedTexts[typedIndex]}
              </motion.h2>
            </div>

            {/* Contact Info */}
            <div className="flex flex-wrap items-center justify-center lg:justify-start gap-4 text-sm text-gray-400 mb-6">
              <a href={`mailto:${portfolio.personal.email}`} className="flex items-center gap-1.5 hover:text-cyan-400 transition-colors">
                <Mail className="w-4 h-4 text-cyan-400" />
                {portfolio.personal.email}
              </a>
              <a href={`tel:${portfolio.personal.phone}`} className="flex items-center gap-1.5 hover:text-cyan-400 transition-colors">
                <Phone className="w-4 h-4 text-cyan-400" />
                {portfolio.personal.phone}
              </a>
              <span className="flex items-center gap-1.5">
                <MapPin className="w-4 h-4 text-cyan-400" />
                {portfolio.personal.location}
              </span>
            </div>

            {/* Bio */}
            <p className="text-gray-400 text-base leading-relaxed max-w-xl mx-auto lg:mx-0 mb-8">
              Expert in cloud infrastructure, CI/CD pipelines, containerization, and monitoring. Built 50+ production-grade automation tools achieving 99.9% uptime across multi-cloud environments.
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-col sm:flex-row items-center justify-center lg:justify-start gap-4 mb-8">
              <Link
                href="/services#contact"
                className="w-full sm:w-auto px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 text-white rounded-xl font-medium hover:shadow-[0_0_30px_rgba(6,182,212,0.5)] transition-all flex items-center justify-center gap-2 group"
              >
                Hire Me
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </Link>
              <Link
                href="#projects"
                className="w-full sm:w-auto px-8 py-4 border border-cyan-500/30 text-cyan-400 rounded-xl font-medium hover:bg-cyan-500/10 transition-colors"
              >
                View My Work
              </Link>
            </div>

            {/* Social Links */}
            <div className="flex items-center justify-center lg:justify-start gap-4">
              <Link
                href={portfolio.socials.github}
                target="_blank"
                rel="noopener noreferrer"
                className="p-3 rounded-xl bg-white/5 text-gray-400 hover:text-cyan-400 hover:bg-white/10 transition-all"
                aria-label="Visit Michael's GitHub Profile"
              >
                <Github className="w-6 h-6" />
              </Link>
              <Link
                href={portfolio.socials.linkedin}
                target="_blank"
                rel="noopener noreferrer"
                className="p-3 rounded-xl bg-white/5 text-gray-400 hover:text-cyan-400 hover:bg-white/10 transition-all"
                aria-label="Visit Michael's LinkedIn Profile"
              >
                <Linkedin className="w-6 h-6" />
              </Link>
            </div>
          </motion.div>

          {/* Right side - Profile Image */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: isVisible ? 1 : 0, scale: isVisible ? 1 : 0.95 }}
            transition={{ duration: 0.4, delay: 0.1 }}
            className="relative flex justify-center"
          >
            <div className="relative">
              {/* Animated glow */}
              <div className="absolute inset-0 bg-gradient-to-r from-cyan-500 via-blue-500 to-purple-500 rounded-full blur-3xl opacity-30 scale-110 animate-pulse" />
              {/* Image container */}
              <div className="relative w-64 h-64 sm:w-80 sm:h-80 lg:w-96 lg:h-96 rounded-full overflow-hidden border-4 border-cyan-500/50 shadow-[0_0_60px_rgba(6,182,212,0.4)]">
                <Image
                  src={portfolio.personal.avatar}
                  alt={`${portfolio.personal.name} - DevOps Engineer`}
                  fill
                  className="object-cover"
                  sizes="(max-width: 640px) 256px, (max-width: 1024px) 320px, 384px"
                  priority
                />
              </div>
            </div>
          </motion.div>
        </div>

        {/* Stats Bar - Animated Count Up */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: isVisible ? 1 : 0, y: isVisible ? 0 : 20 }}
          transition={{ duration: 0.4, delay: 0.2 }}
          className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-16"
        >
          {portfolio.stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: isVisible ? 1 : 0, scale: isVisible ? 1 : 0.8 }}
              transition={{ duration: 0.3, delay: 0.3 + index * 0.1 }}
              className="relative bg-gradient-to-br from-[#0f1020] to-[#141528] rounded-xl border border-cyan-500/20 p-6 text-center hover:border-cyan-500/50 hover:shadow-[0_0_30px_rgba(6,182,212,0.2)] transition-all group overflow-hidden"
            >
              {/* Gradient overlay on hover */}
              <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/0 to-blue-500/0 group-hover:from-cyan-500/10 group-hover:to-blue-500/10 transition-all" />
              
              <div className="relative z-10">
                <div className="text-3xl sm:text-4xl font-bold bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-transparent mb-2">
                  {stat.value}
                </div>
                <div className="text-sm text-gray-400">{stat.label}</div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
