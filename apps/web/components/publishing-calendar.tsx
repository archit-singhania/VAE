"use client";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import { useState } from "react";
import type { ScheduledPost } from "@/lib/api";

const key = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
export function PublishingCalendar({
  posts,
  onChoose,
}: {
  posts: ScheduledPost[];
  onChoose: (date: string) => void;
}) {
  const [month, setMonth] = useState(
    () => new Date(new Date().getFullYear(), new Date().getMonth(), 1),
  );
  const [selected, setSelected] = useState(key(new Date()));
  const start = new Date(month.getFullYear(), month.getMonth(), 1 - ((month.getDay() + 6) % 7));
  const days = Array.from(
    { length: 42 },
    (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i),
  );
  const active = posts.filter((p) => p.status !== "cancelled");
  return (
    <section className="publishing-calendar live-panel">
      <p className="live-kicker">
        <CalendarDays size={14} /> Your publishing rhythm
      </p>
      <div className="calendar-heading">
        <h2>{month.toLocaleDateString(undefined, { month: "long", year: "numeric" })}</h2>
        <div>
          <button
            type="button"
            aria-label="Previous month"
            onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}
          >
            <ChevronLeft size={18} />
          </button>
          <button
            type="button"
            onClick={() => setMonth(new Date(new Date().getFullYear(), new Date().getMonth(), 1))}
          >
            Today
          </button>
          <button
            type="button"
            aria-label="Next month"
            onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}
          >
            <ChevronRight size={18} />
          </button>
        </div>
      </div>
      <div className="calendar-grid">
        {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((d) => (
          <span key={d} className="calendar-weekday">
            {d}
          </span>
        ))}
        {days.map((d) => {
          const id = key(d);
          const count = active.filter((p) => key(new Date(p.scheduled_for)) === id).length;
          return (
            <button
              type="button"
              key={id}
              aria-label={`${d.toLocaleDateString()}: ${count} posts`}
              aria-pressed={selected === id}
              className={`${d.getMonth() !== month.getMonth() ? "calendar-outside" : ""} ${id === key(new Date()) ? "calendar-today" : ""}`}
              onClick={() => {
                setSelected(id);
                onChoose(`${id}T09:00`);
              }}
            >
              <span>{d.getDate()}</span>
              {count > 0 && (
                <small>
                  {count}
                  <span className="calendar-post-label"> post{count === 1 ? "" : "s"}</span>
                </small>
              )}
            </button>
          );
        })}
      </div>
      <p className="live-helper">
        Times use your device timezone: {Intl.DateTimeFormat().resolvedOptions().timeZone}. Select a
        day to prepare a 09:00 schedule; review before confirming.
      </p>
      <div className="calendar-agenda">
        <h3>
          {new Date(`${selected}T12:00`).toLocaleDateString(undefined, {
            weekday: "long",
            month: "short",
            day: "numeric",
          })}
        </h3>
        {active
          .filter((p) => key(new Date(p.scheduled_for)) === selected)
          .map((p) => (
            <article key={p.id}>
              <time>
                {new Date(p.scheduled_for).toLocaleTimeString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                })}
              </time>
              <p>{String(p.payload.text || "Media post").slice(0, 120)}</p>
              <small>{p.status}</small>
            </article>
          ))}
        {!active.some((p) => key(new Date(p.scheduled_for)) === selected) && (
          <p className="live-helper">Space for your next story.</p>
        )}
      </div>
    </section>
  );
}
