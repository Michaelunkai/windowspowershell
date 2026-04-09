import Navbar from "@/components/layout/Navbar";
import ServicesHero from "@/components/services/ServicesHero";
import ProcessSection from "@/components/services/ProcessSection";
import PricingSection from "@/components/services/PricingSection";
import Footer from "@/components/layout/Footer";

export default function ServicesPage() {
  return (
    <>
      <Navbar />
      <main id="services">
        <ServicesHero />
        <ProcessSection />
        <PricingSection />
      </main>
      <Footer />
    </>
  );
}
