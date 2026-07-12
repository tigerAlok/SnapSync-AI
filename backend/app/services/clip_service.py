from io import BytesIO

import numpy as np
import open_clip
import torch
from PIL import Image


class ClipService:
    def __init__(self):
        self.device = (
            "cuda"
            if torch.cuda.is_available()
            else "cpu"
        )

        (
            self.model,
            _,
            self.preprocess,
        ) = open_clip.create_model_and_transforms(
            "ViT-B-32",
            pretrained="laion2b_s34b_b79k",
        )

        self.model.to(
            self.device,
        )

        self.model.eval()

        self.tokenizer = (
            open_clip.get_tokenizer(
                "ViT-B-32",
            )
        )

        # -----------------------------------------
        # CATEGORY PROMPTS
        # -----------------------------------------

        self.category_prompts = {
            "nature": [
                "a natural landscape",
                "mountains and hills",
                "a forest with trees",
                "a river or lake",
                "a waterfall",
                "a beach or ocean",
                "clouds and sky",
                "mountain scenery",
                "an outdoor scenic landscape",
            ],

            "food": [
                "a photo of food",
                "a meal or dish",
                "food served on a plate",
                "restaurant food",
                "snacks or dessert",
                "drinks and beverages",
            ],

            "documents": [
                "a document containing text",
                "a photograph of paper with writing",
                "a question paper or exam sheet",
                "handwritten notes",
                "a receipt or form",
                "a certificate",
                "a screenshot containing mostly text",
            ],

            "animals": [
                "a photo of an animal",
                "a dog",
                "a cat",
                "a pet animal",
                "wildlife",
                "a bird",
            ],

            "vehicles": [
                "a car",
                "a motorcycle",
                "a bus",
                "a truck",
                "a train",
                "a vehicle on a road",
                "a transportation vehicle",
            ],
        }

        # Create text embeddings only once when
        # the backend starts.
        self.category_embeddings = (
            self._create_category_embeddings()
        )

    # ---------------------------------------------
    # IMAGE EMBEDDING
    # ---------------------------------------------

    @torch.no_grad()
    def create_image_embedding(
        self,
        image_bytes: bytes,
    ) -> list[float]:
        image = Image.open(
            BytesIO(image_bytes),
        ).convert("RGB")

        image_tensor = (
            self.preprocess(image)
            .unsqueeze(0)
            .to(self.device)
        )

        embedding = self.model.encode_image(
            image_tensor,
        )

        embedding /= embedding.norm(
            dim=-1,
            keepdim=True,
        )

        return (
            embedding.squeeze()
            .cpu()
            .numpy()
            .astype(np.float32)
            .tolist()
        )

    # ---------------------------------------------
    # TEXT EMBEDDING
    # ---------------------------------------------

    @torch.no_grad()
    def create_text_embedding(
        self,
        text: str,
    ) -> list[float]:
        tokens = self.tokenizer(
            [text],
        ).to(self.device)

        embedding = self.model.encode_text(
            tokens,
        )

        embedding /= embedding.norm(
            dim=-1,
            keepdim=True,
        )

        return (
            embedding.squeeze()
            .cpu()
            .numpy()
            .astype(np.float32)
            .tolist()
        )

    # ---------------------------------------------
    # CACHE CATEGORY TEXT EMBEDDINGS
    # ---------------------------------------------

    @torch.no_grad()
    def _create_category_embeddings(
        self,
    ) -> dict[str, list[np.ndarray]]:
        cached_embeddings = {}

        for category, prompts in (
            self.category_prompts.items()
        ):
            embeddings = []

            for prompt in prompts:
                embedding = (
                    self.create_text_embedding(
                        prompt,
                    )
                )

                embeddings.append(
                    np.asarray(
                        embedding,
                        dtype=np.float32,
                    )
                )

            cached_embeddings[
                category
            ] = embeddings

        return cached_embeddings

    # ---------------------------------------------
    # MULTI-CATEGORY CLASSIFICATION
    # ---------------------------------------------

    @torch.no_grad()
    def classify_categories(
        self,
        image_embedding: list[float],
        minimum_score: float = 0.20,
    ) -> list[dict]:
        image_vector = np.asarray(
            image_embedding,
            dtype=np.float32,
        )

        category_results = []

        for category, text_embeddings in (
            self.category_embeddings.items()
        ):
            scores = [
                float(
                    np.dot(
                        image_vector,
                        text_embedding,
                    )
                )
                for text_embedding
                in text_embeddings
            ]

            best_score = max(
                scores,
            )

            if best_score >= minimum_score:
                category_results.append({
                    "category": category,
                    "score": best_score,
                })

        category_results.sort(
            key=lambda item: item["score"],
            reverse=True,
        )

        return category_results

    # ---------------------------------------------
    # COSINE SIMILARITY
    # ---------------------------------------------

    def similarity(
        self,
        embedding1: list[float],
        embedding2: list[float],
    ) -> float:
        a = np.asarray(
            embedding1,
            dtype=np.float32,
        )

        b = np.asarray(
            embedding2,
            dtype=np.float32,
        )

        return float(
            np.dot(
                a,
                b,
            )
        )


clip_service = ClipService()