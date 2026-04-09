"use client";

import Image from "next/image";
import Link from "next/link";
import { Github } from "lucide-react";
import { motion } from "framer-motion";
import type { Template } from "@/data/portfolio";

interface TemplateCardProps {
  template: Template;
}

export default function TemplateCard({ template }: TemplateCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, ease: "easeOut" }}
      className="bg-[#0f1020] rounded-2xl border border-white/[0.07] overflow-hidden hover:border-accent-purple/30 hover:-translate-y-1 transition-all group"
    >
      {/* Preview Image */}
      <div className="relative h-40 bg-[#141528] overflow-hidden">
        <Image
          src={template.preview}
          alt={template.name}
          fill
          className="object-cover group-hover:scale-105 transition-transform duration-500"
          sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-[#0f1020] to-transparent opacity-60" />
      </div>

      {/* Content */}
      <div className="p-6">
        <div className="flex items-center gap-3 mb-3">
          <div className="relative w-10 h-10 rounded-lg overflow-hidden bg-[#141528]">
            <Image
              src={template.logo}
              alt={`${template.name} logo`}
              fill
              className="object-cover"
              sizes="40px"
            />
          </div>
          <h3 className="text-lg font-semibold text-white">{template.name}</h3>
        </div>

        <p className="text-gray-400 text-sm mb-4 line-clamp-2">
          {template.description}
        </p>

        <Link
          href={template.githubUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 text-sm text-accent-purpleLight hover:text-white transition-colors"
        >
          <Github className="w-4 h-4" />
          View on GitHub
        </Link>
      </div>
    </motion.div>
  );
}
