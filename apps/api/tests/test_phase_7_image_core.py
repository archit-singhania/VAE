import io

import pytest
from PIL import Image, ImageDraw

from aevra_api.media.huggingface_provider import HuggingFaceImageProvider
from aevra_api.media.image_contracts import ImageGenerationRequest, ImagePipelineError
from aevra_api.media.image_renderer import DeterministicImageProvider
from aevra_api.media.image_transforms import (
    BrandVisualStyle,
    apply_brand_overlay,
    encode_image,
    resize_contain,
    resize_cover,
)


def _open(data: bytes) -> Image.Image:
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        return image.copy()


def test_deterministic_provider_retries_to_identical_offline_asset() -> None:
    provider = DeterministicImageProvider()
    request = ImageGenerationRequest(
        prompt="  A premium abstract launch visual for evidence-led AI.  ",
        width=256,
        height=160,
        style="Editorial",
    )

    first = provider.generate(request)
    second = provider.generate(request)

    assert request.prompt == "A premium abstract launch visual for evidence-led AI."
    assert request.style == "editorial"
    assert first.image.data == second.image.data
    assert first.image.sha256 == second.image.sha256
    assert first.seed == second.seed
    assert first.image.content_type == "image/png"
    assert first.metadata["offline"] is True
    assert _open(first.image.data).size == (256, 160)
    assert provider.status().available is True


def test_seed_and_format_change_are_explicit_and_traceable() -> None:
    provider = DeterministicImageProvider()
    first = provider.generate(
        ImageGenerationRequest(
            prompt="A modular product system in a dark studio",
            width=192,
            height=192,
            seed=7,
        )
    )
    second = provider.generate(
        ImageGenerationRequest(
            prompt="A modular product system in a dark studio",
            width=192,
            height=192,
            seed=8,
            output_format="jpeg",
        )
    )

    assert first.seed == 7
    assert second.seed == 8
    assert first.image.sha256 != second.image.sha256
    assert second.image.content_type == "image/jpeg"
    assert _open(second.image.data).mode == "RGB"


def test_request_rejects_unsafe_or_ambiguous_image_inputs() -> None:
    with pytest.raises(ImagePipelineError, match="prompt"):
        ImageGenerationRequest(prompt=" ")
    with pytest.raises(ImagePipelineError, match="image may not exceed"):
        ImageGenerationRequest(prompt="x", width=4096, height=4096)
    with pytest.raises(ImagePipelineError, match="seed"):
        ImageGenerationRequest(prompt="x", seed=-1)
    with pytest.raises(ImagePipelineError, match="style"):
        ImageGenerationRequest(prompt="x", style="A polished / unsafe style")


def test_cover_crop_respects_requested_focal_side_without_mutating_source() -> None:
    source = Image.new("RGB", (200, 100), "#e11d48")
    ImageDraw.Draw(source).rectangle((100, 0, 199, 99), fill="#2563eb")
    original = source.copy()

    left = resize_cover(source, 64, 64, focus=(0.0, 0.5))
    right = resize_cover(source, 64, 64, focus=(1.0, 0.5))

    assert left.size == (64, 64)
    assert right.size == (64, 64)
    left_pixel = left.getpixel((32, 32))
    right_pixel = right.getpixel((32, 32))
    assert isinstance(left_pixel, tuple) and isinstance(right_pixel, tuple)
    assert left_pixel[0] > left_pixel[2]
    assert right_pixel[2] > right_pixel[0]
    assert source.tobytes() == original.tobytes()
    with pytest.raises(ImagePipelineError, match="focus"):
        resize_cover(source, 64, 64, focus=(1.1, 0.5))


def test_contain_brand_overlay_and_encoding_are_safe_and_repeatable() -> None:
    source = Image.new("RGB", (160, 80), "#0ea5e9")
    contained = resize_contain(source, 192, 192, background_color="#111827")
    assert contained.size == (192, 192)
    assert contained.getpixel((10, 10)) == (17, 24, 39)
    assert contained.getpixel((96, 96)) == (14, 165, 233)

    logo = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ImageDraw.Draw(logo).ellipse((8, 8, 56, 56), fill="#f7c95c")
    logo_bytes = encode_image(logo).data
    style = BrandVisualStyle(
        primary_color="#6D5EF7",
        secondary_color="#0B1020",
        accent_color="#F7C95C",
        logo_png=logo_bytes,
        logo_position="top_right",
        label="Aevra Studio",
    )
    original = encode_image(contained).data
    first = apply_brand_overlay(contained, style)
    second = apply_brand_overlay(contained, style)
    encoded = encode_image(first, "webp")

    assert encode_image(contained).data == original
    assert encode_image(first).data == encode_image(second).data
    assert encode_image(first).data != original
    assert encoded.content_type == "image/webp"
    assert encoded.width == encoded.height == 192
    assert _open(encoded.data).size == (192, 192)


def test_brand_overlay_rejects_invalid_logo_payload_at_decode_boundary() -> None:
    style = BrandVisualStyle(logo_png=b"not an image")
    with pytest.raises(ImagePipelineError, match="safely decoded"):
        apply_brand_overlay(Image.new("RGB", (128, 128), "black"), style)


def test_huggingface_provider_returns_real_provider_image_with_provenance() -> None:
    class FakeInferenceClient:
        def text_to_image(self, prompt: str, **kwargs: object) -> Image.Image:
            assert prompt == "A cinematic animated runner"
            assert kwargs["model"] == "black-forest-labs/FLUX.1-schnell"
            return Image.new("RGB", (256, 256), "#2563eb")

    provider = HuggingFaceImageProvider(
        "hf_test_token",
        "black-forest-labs/FLUX.1-schnell",
        client=FakeInferenceClient(),
    )
    result = provider.generate(
        ImageGenerationRequest(
            prompt="A cinematic animated runner", width=256, height=256, seed=42
        )
    )

    assert provider.status().available is True
    assert result.provider == "huggingface-inference"
    assert result.model == "black-forest-labs/FLUX.1-schnell"
    assert result.seed == 42
    assert result.metadata["remote"] is True
    assert _open(result.image.data).size == (256, 256)
