"use client";

import { motion } from "framer-motion";
import { MessageSquare, Rocket, Activity, Server, Check, Star } from "lucide-react";
import { fadeUp, fadeUpProps } from "@/lib/animations";
import { portfolio } from "@/data/portfolio";
import type { Service } from "@/data/portfolio";

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  MessageSquare,
  Rocket,
  Activity,
  Server,
};

const colorMap: Record<string, { text: string; bg: string; border: string }> = {
  blue: {
    text: "text-accent-blue",
    bg: "bg-accent-blue",
    border: "border-accent-blue/30",
  },
  purple: {
    text: "text-accent-purple",
    bg: "bg-accent-purple",
    border: "border-accent-purple/30",
  },
  green: {
    text: "text-accent-green",
    bg: "bg-accent-green",
    border: "border-accent-green/30",
  },
  orange: {
    text: "text-orange-500",
    bg: "bg-orange-500",
    border: "border-orange-500/30",
  },
};

function ServiceCard({
  service,
  index,
}: {
  service: Service;
  index: number;
}) {
  const Icon = iconMap[service.icon] || MessageSquare;
  const colors = colorMap[service.accentColor] || colorMap.purple;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, ease: [0.25, 0.1, 0.25, 1], delay: index * 0.1 }}
      className={`relative bg-[#0f1020] rounded-2xl border ${
        service.popular ? colors.border : "border-white/[0.07]"
      } p-6 hover:border-accent-purple/30 transition-all ${
        service.popular ? "lg:-translate-y-4" : ""
      }`}
    >
      {/* Popular Badge */}
      {service.popular && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 bg-accent-purple rounded-full text-white text-xs font-medium flex items-center gap-1">
          <Star className="w-3 h-3 fill-current" />
          Most Popular
        </div>
      )}

      {/* Icon */}
      <div
        className={`w-12 h-12 rounded-xl ${colors.bg}/10 flex items-center justify-center mb-4`}
      >
        <Icon className={`w-6 h-6 ${colors.text}`} />
      </div>

      {/* Title */}
      <h3 className={`text-xl font-semibold ${colors.text} mb-2`}>
        {service.name}
      </h3>

      {/* Description */}
      <p className="text-gray-400 text-sm mb-4">{service.description}</p>

      {/* Features */}
      <ul className="space-y-2 mb-6">
        {service.features.map((feature) => (
          <li key={feature} className="flex items-center gap-2 text-sm">
            <Check className={`w-4 h-4 ${colors.text} flex-shrink-0`} />
            <span className="text-gray-300">{feature}</span>
          </li>
        ))}
      </ul>

      {/* Price */}
      <div className="text-2xl font-bold text-white mb-4">{service.price}</div>

      {/* CTA Button */}
      <a
        href="#contact"
        className={`block w-full py-3 rounded-xl font-medium text-center transition-colors ${
          service.popular
            ? `${colors.bg} text-white hover:opacity-90`
            : `border ${colors.border} ${colors.text} hover:bg-white/5`
        }`}
      >
        Get Started
      </a>
    </motion.div>
  );
}

export default function PricingSection() {
  return (
    <section id="services" className="py-20 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <motion.div variants={fadeUp} {...fadeUpProps} className="text-center mb-12">
          <h2 className="text-3xl sm:text-4xl font-bold text-white mb-4">
            Services & Pricing
          </h2>
          <p className="text-gray-400 max-w-2xl mx-auto">
            Professional DevOps and infrastructure services tailored to your needs.
            All packages include dedicated support and comprehensive documentation.
          </p>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {portfolio.services.map((service, index) => (
            <ServiceCard key={service.id} service={service} index={index} />
          ))}
        </div>
      </div>
    </section>
  );
}
