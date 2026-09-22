import json
from collections.abc import Iterator

import httpx

from aevra_api.ai.contracts import (
    GenerationRequest,
    GenerationResult,
    LLMProvider,
    ProviderStatus,
)
from aevra_api.config import Settings
from aevra_api.domain.errors import ProviderUnavailableError


class OllamaLLMProvider:
    def __init__(self, settings: Settings, client: httpx.Client | None = None) -> None:
        self.settings = settings
        self.client = client or httpx.Client(
            base_url=settings.ollama_base_url.rstrip("/"),
            timeout=settings.ollama_timeout_seconds,
        )

    @property
    def model_name(self) -> str:
        return self.settings.ollama_model

    def status(self) -> ProviderStatus:
        try:
            response = self.client.get("/api/tags")
            response.raise_for_status()
            models = response.json().get("models", [])
            installed = any(
                item.get("name") == self.model_name or item.get("model") == self.model_name
                for item in models
                if isinstance(item, dict)
            )
            detail = (
                "Model is installed and ready" if installed else "Ollama is ready; model not found"
            )
            return ProviderStatus(installed, "ollama", self.model_name, detail)
        except (httpx.HTTPError, ValueError, AttributeError):
            return ProviderStatus(False, "ollama", self.model_name, "Ollama is unavailable")

    def generate(self, request: GenerationRequest) -> GenerationResult:
        payload: dict[str, object] = {
            "model": self.model_name,
            "stream": False,
            "messages": [
                {"role": message.role, "content": message.content} for message in request.messages
            ],
            "options": {
                "temperature": request.temperature,
                "num_predict": request.max_tokens,
            },
        }
        if request.response_format == "json":
            payload["format"] = "json"
        try:
            response = self.client.post("/api/chat", json=payload)
            response.raise_for_status()
            body = response.json()
            content = body["message"]["content"]
        except (httpx.HTTPError, ValueError, KeyError, TypeError) as exc:
            raise ProviderUnavailableError("Local language model is unavailable") from exc
        if not isinstance(content, str) or not content.strip():
            raise ProviderUnavailableError("Local language model returned an empty response")
        return GenerationResult(
            content=content,
            model=body.get("model", self.model_name),
            provider="ollama",
            prompt_tokens=body.get("prompt_eval_count"),
            completion_tokens=body.get("eval_count"),
            metadata={"done": bool(body.get("done", True))},
        )

    def stream(self, request: GenerationRequest) -> Iterator[str]:
        """Yield Ollama's newline-delimited response chunks as they arrive."""
        payload: dict[str, object] = {
            "model": self.model_name,
            "stream": True,
            "messages": [
                {"role": message.role, "content": message.content} for message in request.messages
            ],
            "options": {"temperature": request.temperature, "num_predict": request.max_tokens},
        }
        if request.response_format == "json":
            payload["format"] = "json"
        try:
            with self.client.stream("POST", "/api/chat", json=payload) as response:
                response.raise_for_status()
                for line in response.iter_lines():
                    if not line:
                        continue
                    body = __import__("json").loads(line)
                    chunk = body.get("message", {}).get("content", "")
                    if isinstance(chunk, str) and chunk:
                        yield chunk
        except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
            raise ProviderUnavailableError("Local language model streaming is unavailable") from exc


class GroqLLMProvider:
    """OpenAI-compatible Groq provider; enabled only when a server-side key exists."""

    def __init__(self, settings: Settings, client: httpx.Client | None = None) -> None:
        if not settings.groq_api_key:
            raise ValueError("Groq API key is not configured")
        self.settings = settings
        self.client = client or httpx.Client(
            base_url=settings.groq_base_url.rstrip("/"),
            timeout=settings.groq_timeout_seconds,
            headers={"Authorization": f"Bearer {settings.groq_api_key}"},
        )

    @property
    def model_name(self) -> str:
        return self.settings.groq_model

    def status(self) -> ProviderStatus:
        return ProviderStatus(
            bool(self.settings.groq_api_key), "groq", self.model_name, "Groq configured"
        )

    def _payload(self, request: GenerationRequest, *, stream: bool) -> dict[str, object]:
        payload: dict[str, object] = {
            "model": self.model_name,
            "stream": stream,
            "messages": [{"role": m.role, "content": m.content} for m in request.messages],
            "temperature": request.temperature,
            "max_tokens": request.max_tokens,
        }
        if request.response_format == "json":
            payload["response_format"] = {"type": "json_object"}
        return payload

    def generate(self, request: GenerationRequest) -> GenerationResult:
        try:
            response = self.client.post(
                "/chat/completions", json=self._payload(request, stream=False)
            )
            response.raise_for_status()
            body = response.json()
            content = body["choices"][0]["message"]["content"]
        except (httpx.HTTPError, ValueError, KeyError, TypeError, IndexError) as exc:
            raise ProviderUnavailableError("Groq language model is unavailable") from exc
        if not isinstance(content, str) or not content.strip():
            raise ProviderUnavailableError("Groq language model returned an empty response")
        usage = body.get("usage", {}) if isinstance(body, dict) else {}
        return GenerationResult(
            content=content,
            model=str(body.get("model", self.model_name)),
            provider="groq",
            prompt_tokens=usage.get("prompt_tokens") if isinstance(usage, dict) else None,
            completion_tokens=usage.get("completion_tokens") if isinstance(usage, dict) else None,
            metadata={"done": True},
        )

    def stream(self, request: GenerationRequest) -> Iterator[str]:
        try:
            with self.client.stream(
                "POST", "/chat/completions", json=self._payload(request, stream=True)
            ) as response:
                response.raise_for_status()
                for line in response.iter_lines():
                    if not line or not line.startswith("data:"):
                        continue
                    raw = line.removeprefix("data:").strip()
                    if raw == "[DONE]":
                        break
                    chunk = (
                        json.loads(raw)
                        .get("choices", [{}])[0]
                        .get("delta", {})
                        .get("content", "")
                    )
                    if isinstance(chunk, str) and chunk:
                        yield chunk
        except (httpx.HTTPError, ValueError, TypeError, KeyError, IndexError) as exc:
            raise ProviderUnavailableError("Groq language model streaming is unavailable") from exc


class FallbackLLMProvider:
    """Use local Ollama first and Groq as an opt-in server-side fallback."""

    def __init__(self, primary: OllamaLLMProvider, fallback: GroqLLMProvider) -> None:
        self.primary = primary
        self.fallback = fallback

    @property
    def model_name(self) -> str:
        return f"{self.primary.model_name} → {self.fallback.model_name}"

    def status(self) -> ProviderStatus:
        primary = self.primary.status()
        return primary if primary.available else self.fallback.status()

    def generate(self, request: GenerationRequest) -> GenerationResult:
        try:
            return self.primary.generate(request)
        except ProviderUnavailableError:
            return self.fallback.generate(request)

    def stream(self, request: GenerationRequest) -> Iterator[str]:
        try:
            yield from self.primary.stream(request)
        except ProviderUnavailableError:
            yield from self.fallback.stream(request)


def build_llm_provider(settings: Settings) -> LLMProvider:
    primary = OllamaLLMProvider(settings)
    if settings.groq_api_key:
        return FallbackLLMProvider(primary, GroqLLMProvider(settings))
    return primary
