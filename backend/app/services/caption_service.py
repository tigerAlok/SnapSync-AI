from io import BytesIO

import torch
from PIL import Image
from transformers import (
    BlipForConditionalGeneration,
    BlipProcessor,
)


class CaptionService:
    def __init__(self):
        self.device = (
            "cuda"
            if torch.cuda.is_available()
            else "cpu"
        )

        model_name = (
            "Salesforce/"
            "blip-image-captioning-base"
        )

        self.processor = (
            BlipProcessor.from_pretrained(
                model_name,
            )
        )

        self.model = (
            BlipForConditionalGeneration
            .from_pretrained(
                model_name,
            )
        )

        self.model.to(
            self.device,
        )

        self.model.eval()

    @torch.no_grad()
    def generate_caption(
        self,
        image_bytes: bytes,
    ) -> str:
        image = Image.open(
            BytesIO(image_bytes),
        ).convert("RGB")

        inputs = self.processor(
            images=image,
            return_tensors="pt",
        )

        inputs = {
            key: value.to(self.device)
            for key, value in inputs.items()
        }

        output_ids = self.model.generate(
            **inputs,
            max_new_tokens=40,
            num_beams=3,
        )

        caption = self.processor.decode(
            output_ids[0],
            skip_special_tokens=True,
        )

        return caption.strip()


caption_service = CaptionService()