from io import BytesIO

import cv2
import numpy as np
from PIL import Image


class ImageQualityService:
    def calculate_quality(
        self,
        image_bytes: bytes,
    ) -> dict:
        image = Image.open(
            BytesIO(image_bytes),
        ).convert("RGB")

        image_array = np.asarray(
            image,
        )

        height, width = image_array.shape[:2]

        gray = cv2.cvtColor(
            image_array,
            cv2.COLOR_RGB2GRAY,
        )

        # Higher variance generally means
        # a sharper image.
        sharpness = float(
            cv2.Laplacian(
                gray,
                cv2.CV_64F,
            ).var()
        )

        megapixels = float(
            (width * height) / 1_000_000
        )

        # Simple combined score.
        quality_score = float(
            sharpness
            + (megapixels * 20.0)
        )

        return {
            "width": int(width),
            "height": int(height),
            "megapixels": megapixels,
            "sharpness": sharpness,
            "qualityScore": quality_score,
        }


image_quality_service = ImageQualityService()