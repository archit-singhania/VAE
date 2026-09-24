"use client";
import {
  ArrowUpRight,
  BrainCircuit,
  CalendarDays,
  Layers,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import { motion } from "motion/react";

export function LandingStory() {
  return (
    <section className="landing-story" aria-label="Explore VAE">
      <div className="landing-story-heading">
        <p className="live-kicker">From a spark to a story</p>
        <h2>
          One thoughtful space.
          <br />
          <em>Every part of your creative day.</em>
        </h2>
        <p>
          Create with intention. Pair the right words and visuals. Find a rhythm your audience can
          look forward to.
        </p>
      </div>
      <div className="landing-story-grid">
        {[
          {
            icon: Sparkles,
            n: "01",
            title: "Make the idea tangible",
            text: "Turn a brief into images and social copy. Keep your brand references close and bring your own finished assets when you publish.",
          },
          {
            icon: Layers,
            n: "02",
            title: "Give every visual a voice",
            text: "Write, generate, or import captions and hashtags. Pair them with an image whenever inspiration arrives.",
          },
          {
            icon: CalendarDays,
            n: "03",
            title: "Publish with a clear view",
            text: "Connect your channels, review the complete post, and choose now or later. Follow delivery from one calendar.",
          },
        ].map((item, i) => (
          <motion.article
            key={item.n}
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, amount: 0.2 }}
            transition={{ duration: 0.55, delay: i * 0.08 }}
          >
            <div>
              <item.icon size={24} />
              <span>{item.n}</span>
            </div>
            <h3>{item.title}</h3>
            <p>{item.text}</p>
            <ArrowUpRight size={18} />
          </motion.article>
        ))}
      </div>
      <div className="landing-insight-strip">
        <BrainCircuit size={32} />
        <div>
          <p className="live-kicker">13 tools for a more informed next move</p>
          <h3>Let your own history teach you.</h3>
          <p>
            Explore content patterns, compare draft predictions, and check the quality of your data.
            Insights show their limits when there is not enough evidence.
          </p>
        </div>
        <div className="landing-orbit" aria-hidden="true">
          <span />
          <span />
          <span />
        </div>
      </div>
      <footer>
        <span>
          <ShieldCheck size={16} />
          Workspace-scoped insights. You stay in control.
        </span>
        <span>VAE · Create. Publish. Understand.</span>
      </footer>
    </section>
  );
}
