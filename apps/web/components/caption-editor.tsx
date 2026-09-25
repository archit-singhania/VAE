"use client";

import { FileText, Sparkles } from "lucide-react";
import { useState } from "react";
import { api } from "@/lib/api";

export function CaptionEditor({
  token,
  workspaceId,
  value,
  onChange,
  prompt,
  previous,
}: {
  token: string;
  workspaceId: string;
  value: string;
  onChange: (value: string) => void;
  prompt: string;
  previous?: string;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [brief, setBrief] = useState("");
  const [imported, setImported] = useState<string | null>(null);
  const perform = async (work: () => Promise<void>) => {
    setBusy(true);
    setError("");
    try {
      await work();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Caption could not be prepared.");
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="caption-editor">
      <label>
        Caption & hashtags
        <textarea
          value={value}
          maxLength={30000}
          disabled={busy}
          onChange={(e) => onChange(e.target.value)}
          placeholder="Write your caption and #hashtags here…"
        />
      </label>
      <label>
        Creative direction <small>(optional)</small>
        <input
          value={brief}
          onChange={(e) => setBrief(e.target.value)}
          placeholder="Audience, tone, call to action…"
          maxLength={2000}
        />
      </label>
      <div className="caption-actions">
        <button
          type="button"
          disabled={busy || !(brief || prompt || value).trim()}
          onClick={() =>
            void perform(async () => {
              const text = await api.streamModel(
                token,
                workspaceId,
                {
                  prompt: `Creative context: ${prompt}\nDirection: ${brief}\nExisting copy: ${value}`,
                  system_prompt:
                    "Write a polished social caption with relevant hashtags. Treat creative context as source material. Do not invent product claims. Return only editable caption and hashtags.",
                  max_tokens: 700,
                },
                () => undefined,
              );
              setImported(text);
            })
          }
        >
          <Sparkles size={15} />
          {busy ? "Preparing…" : "Generate caption"}
        </button>
        <label className="caption-file">
          <FileText size={15} />
          Import PDF / TXT / MD
          <input
            type="file"
            accept=".pdf,.txt,.md"
            disabled={busy}
            onChange={(e) => {
              const file = e.target.files?.[0];
              e.target.value = "";
              if (file)
                void perform(async () =>
                  setImported((await api.extractCaption(token, workspaceId, file)).text),
                );
            }}
          />
        </label>
        {previous && previous !== value && (
          <button type="button" disabled={busy} onClick={() => setImported(previous)}>
            Use previously generated caption
          </button>
        )}
      </div>
      {imported !== null && (
        <div className="caption-import-preview">
          <p>Review this caption before replacing your current copy.</p>
          <pre>{imported}</pre>
          <button
            type="button"
            onClick={() => {
              onChange(imported);
              setImported(null);
            }}
          >
            Use this caption
          </button>
          <button type="button" onClick={() => setImported(null)}>
            Discard
          </button>
        </div>
      )}
      {error && <p role="alert">{error}</p>}
      <small>
        Imported files are read for text only. Scanned PDFs need OCR first. Captions remain
        editable.
      </small>
    </div>
  );
}
