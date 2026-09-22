"""Deterministic, provider-neutral media primitives for Aevra.

The package deliberately keeps rendering and composition in-memory. Persistence,
tenant authorization, and delivery URLs belong to the service layer.
"""

from aevra_api.media.huggingface_provider import HuggingFaceImageProvider
from aevra_api.media.image_contracts import (
    EncodedImage,
    ImageGenerationRequest,
    ImageGenerationResult,
    ImagePipelineError,
    ImageProvider,
)
from aevra_api.media.image_renderer import DeterministicImageProvider
from aevra_api.media.image_transforms import (
    BrandVisualStyle,
    apply_brand_overlay,
    encode_image,
    resize_contain,
    resize_cover,
)

__all__ = [
    "BrandVisualStyle",
    "DeterministicImageProvider",
    "EncodedImage",
    "ImageGenerationRequest",
    "ImageGenerationResult",
    "ImagePipelineError",
    "ImageProvider",
    "HuggingFaceImageProvider",
    "apply_brand_overlay",
    "encode_image",
    "resize_contain",
    "resize_cover",
]
