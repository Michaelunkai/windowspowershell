import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import ScrollToTop from "@/components/ScrollToTop";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Michael Fedorovsky | DevOps Engineer & System Administrator",
  description:
    "Results-driven DevOps Engineer with expertise in cloud infrastructure, CI/CD automation, container orchestration, and monitoring systems. 50+ automation tools built. Expert in AWS, Docker, Kubernetes, Prometheus/Grafana, and Python/Bash scripting.",
  keywords: [
    "DevOps Engineer",
    "System Administrator",
    "Cloud Engineer",
    "AWS",
    "Docker",
    "Kubernetes",
    "CI/CD",
    "GitHub Actions",
    "Terraform",
    "Ansible",
    "Prometheus",
    "Grafana",
    "Infrastructure Automation",
    "Michael Fedorovsky",
    "Israel DevOps",
  ],
  authors: [{ name: "Michael Fedorovsky" }],
  metadataBase: new URL("https://michaelunkai.github.io/portfolio-website"),
  openGraph: {
    title: "Michael Fedorovsky | DevOps Engineer",
    description:
      "Results-driven DevOps Engineer with expertise in cloud infrastructure, CI/CD automation, and container orchestration. 50+ automation tools built.",
    url: "https://michaelunkai.github.io/portfolio-website",
    siteName: "Michael Fedorovsky Portfolio",
    type: "website",
    images: [
      {
        url: "/images/avatar.jpg",
        width: 1200,
        height: 630,
        alt: "Michael Fedorovsky - DevOps Engineer",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Michael Fedorovsky | DevOps Engineer",
    description:
      "Results-driven DevOps Engineer with expertise in cloud infrastructure, CI/CD automation, and container orchestration.",
    images: ["/images/avatar.jpg"],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <head>
        <link rel="icon" href="/favicon.ico" sizes="any" />
        <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
      </head>
      <body className={`${inter.variable} font-sans antialiased`}>
        {children}
        <ScrollToTop />
      </body>
    </html>
  );
}
