"use client";

import { motion } from "framer-motion";
import { MessageSquare, Code2, Server, Rocket } from "lucide-react";
import type { ProcessStep } from "@/data/portfolio";

interface ProcessCardProps {
  step: ProcessStep;
  index: number;
}

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  MessageSquare,
  Code2,
  Server,
  Rocket,
};

export default function ProcessCard({ step, index }: ProcessCardProps) {
  const Icon = iconMap[step.icon] || MessageSquare;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2, margin: "0px 0px -50px 0px" }}
      transition={{ duration: 0.3, delay: index * 0.05 }}
      className="relative bg-gradient-to-br from-[#0f1020] to-[#141528] rounded-2xl border border-white/[0.07] p-6 hover:border-cyan-500/50 transition-all group"
    >
      {/* Large Step Number Badge */}
      <div className="absolute -top-4 -right-4 w-12 h-12 rounded-full bg-gradient-to-br from-cyan-500 to-blue-600 flex items-center justify-center text-white text-xl font-bold shadow-[0_0_20px_rgba(6,182,212,0.5)]">
        {step.step}
      </div>

      {/* Gradient Icon Container */}
      <div
        className={`w-14 h-14 rounded-xl bg-gradient-to-br ${step.gradient} flex items-center justify-center mb-4 group-hover:scale-110 transition-transform`}
      >
        <Icon className="w-7 h-7 text-white" />
      </div>

      {/* Step Name */}
      <h3 className="text-xl font-semibold text-white mb-3">{step.name}</h3>

      {/* Description */}
      <p className="text-gray-400 text-sm leading-relaxed">{step.description}</p>
    </motion.div>
  );
}
