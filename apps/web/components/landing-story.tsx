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

type LandingAudience = "creator" | "admin";

export function LandingStory({ audience = "creator" }: { audience?: LandingAudience }) {
  const isAdmin = audience === "admin";
  const cards = isAdmin
    ? [
        {
          icon: Layers,
          n: "01",
          title: "See customer health clearly",
          text: "Follow adoption, workspace activity and publishing outcomes through operational KPIs.",
        },
        {
          icon: BrainCircuit,
          n: "02",
          title: "Understand product usage",
          text: "Review aggregate generation activity, model usage and channel performance across customer workspaces.",
        },
        {
          icon: ShieldCheck,
          n: "03",
          title: "Review with care",
          text: "Keep payment decisions and account operations in a dedicated administrator workspace.",
        },
      ]
    : [
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
      ];

  return (
    <section
      className="landing-story"
      aria-label={isAdmin ? "Administrator workspace overview" : "Explore VAE"}
    >
      <div className="landing-story-heading">
        <p className="live-kicker">
          {isAdmin ? "Clarity for the people behind the platform" : "From a spark to a story"}
        </p>
        <h2>
          {isAdmin ? "A considered view." : "One thoughtful space."}
          <br />
          <em>{isAdmin ? "Every operation, in context." : "Every part of your creative day."}</em>
        </h2>
        <p>
          {isAdmin
            ? "Understand customer adoption, publishing health and payment review from one focused operations workspace."
            : "Create with intention. Pair the right words and visuals. Find a rhythm your audience can look forward to."}
        </p>
      </div>
      <div className="landing-story-grid">
        {cards.map((item, i) => (
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
        {isAdmin ? <ShieldCheck size={32} /> : <BrainCircuit size={32} />}
        <div>
          <p className="live-kicker">
            {isAdmin
              ? "A calmer way to run the platform"
              : "13 tools for a more informed next move"}
          </p>
          <h3>
            {isAdmin
              ? "Good operations start with useful signals."
              : "Let your own history teach you."}
          </h3>
          <p>
            {isAdmin
              ? "Move between customer KPIs, AI and media usage, publishing analytics and payment review in a dedicated administrator workspace."
              : "Explore content patterns, compare draft predictions, and check the quality of your data. Insights show their limits when there is not enough evidence."}
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
          {isAdmin
            ? "Operational KPIs with clear context."
            : "Workspace-scoped insights. You stay in control."}
        </span>
        <span>
          {isAdmin ? "VAE · Thoughtful customer operations." : "VAE · Create. Publish. Understand."}
        </span>
      </footer>
    </section>
  );
}
