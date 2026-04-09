import Navbar from "@/components/layout/Navbar";
import HeroSection from "@/components/home/HeroSection";
import FocusSection from "@/components/home/FocusSection";
import FeaturedProject from "@/components/home/FeaturedProject";
import ProjectsSection from "@/components/home/ProjectsSection";
import AboutSection from "@/components/home/AboutSection";
import TeamSection from "@/components/home/TeamSection";
import Footer from "@/components/layout/Footer";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <section id="home">
          <HeroSection />
        </section>
        <FocusSection />
        <FeaturedProject />
        <section id="projects">
          <ProjectsSection />
        </section>
        <AboutSection />
        <TeamSection />
      </main>
      <Footer />
    </>
  );
}
