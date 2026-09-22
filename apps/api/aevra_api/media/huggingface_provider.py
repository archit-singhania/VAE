from __future__ import annotations

from typing import Any

from PIL import Image

from aevra_api.ai.contracts import ProviderStatus
from aevra_api.domain.errors import GenerationError, ProviderUnavailableError
from aevra_api.media.image_contracts import ImageGenerationRequest, ImageGenerationResult
from aevra_api.media.image_transforms import BrandVisualStyle, apply_brand_overlay, encode_image


class HuggingFaceImageProvider:
    """Generate real diffusion images through Hugging Face Inference Providers."""

    provider_name = "huggingface-inference"

    def __init__(
        self,
        token: str | None,
        model: str,
        *,
        provider: str = "fal-ai",
        timeout_seconds: float = 120.0,
        client: Any = None,
    ) -> None:
        self.token = token.strip() if token else ""
        self._model_name = model.strip()
        self.provider = provider.strip() or "fal-ai"
        self.timeout_seconds = timeout_seconds
        self._client = client

    @property
    def model_name(self) -> str:
        return self._model_name

    def status(self) -> ProviderStatus:
        available = bool(self.token and self._model_name)
        return ProviderStatus(
            available=available,
            provider=self.provider_name,
            model=self._model_name,
            detail=(
                "Hugging Face image generation is configured."
                if available
                else "AEVRA_HUGGINGFACE_API_TOKEN is required for AI image generation."
            ),
        )

    def _get_client(self) -> Any:
        if self._client is not None:
            return self._client
        if not self.token:
            raise ProviderUnavailableError(
                "AI image generation is not configured. Add AEVRA_HUGGINGFACE_API_TOKEN in Render."
            )
        try:
            from huggingface_hub import InferenceClient  # type: ignore[import-not-found]
        except ImportError as error:  # pragma: no cover - packaging guard
            raise ProviderUnavailableError(
                "Hugging Face image support is not installed."
            ) from error
        self._client = InferenceClient(
            provider=self.provider,
            api_key=self.token,
            timeout=self.timeout_seconds,
        )
        return self._client

    def generate(
        self,
        request: ImageGenerationRequest,
        *,
        brand_style: BrandVisualStyle | None = None,
    ) -> ImageGenerationResult:
        if not self._model_name:
            raise ProviderUnavailableError("A Hugging Face image model has not been configured.")
        try:
            generated = self._get_client().text_to_image(
                request.prompt,
                model=self._model_name,
                negative_prompt=request.negative_prompt or None,
                width=request.width,
                height=request.height,
                seed=request.seed,
            )
            if not isinstance(generated, Image.Image):
                raise TypeError("provider did not return an image")
            image = generated.convert("RGBA")
            if brand_style is not None:
                image = apply_brand_overlay(image, brand_style)
            encoded = encode_image(image, request.output_format)
        except ProviderUnavailableError:
            raise
        except Exception as error:
            message = str(error).lower()
            if any(term in message for term in ("credit", "quota", "429", "rate limit")):
                raise ProviderUnavailableError(
                    "Hugging Face image credits are exhausted or rate-limited. Try again later."
                ) from error
            if any(term in message for term in ("401", "403", "unauthorized", "forbidden")):
                raise ProviderUnavailableError(
                    "The Hugging Face token is invalid or lacks Inference Providers permission."
                ) from error
            raise GenerationError("The AI image provider could not generate this image.") from error

        return ImageGenerationResult(
            image=encoded,
            provider=self.provider_name,
            model=self._model_name,
            seed=request.seed or 0,
            metadata={"remote": True, "inference_provider": self.provider},
        )
