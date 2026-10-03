import { cn } from "@/lib/utils";

export function BrandIdentity({
  audience = "creator",
  className,
}: {
  audience?: "creator" | "admin";
  className?: string;
}) {
  return (
    <div
      className={cn("premium-brand", `premium-brand-${audience}`, className)}
      role="img"
      aria-label={audience === "admin" ? "VAE administration" : "VAE creator and business"}
    >
      {/* biome-ignore lint/performance/noImgElement: locally shipped vector brand mark */}
      <img
        src={
          audience === "admin" ? "/branding/vae_admin_mark.svg" : "/branding/vae_creator_mark.svg"
        }
        alt=""
        width={44}
        height={44}
      />
      <div className="premium-brand-copy" aria-hidden="true">
        <strong>VAE</strong>
        <small>{audience === "admin" ? "ADMINISTRATION" : "CREATIVE STUDIO"}</small>
      </div>
    </div>
  );
}
