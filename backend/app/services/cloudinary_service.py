import os

import cloudinary
import cloudinary.uploader
from dotenv import load_dotenv


load_dotenv()


cloudinary.config(
    cloud_name=os.getenv(
        "CLOUDINARY_CLOUD_NAME",
    ),
    api_key=os.getenv(
        "CLOUDINARY_API_KEY",
    ),
    api_secret=os.getenv(
        "CLOUDINARY_API_SECRET",
    ),
    secure=True,
)


class CloudinaryService:
    def delete_image(
        self,
        public_id: str,
    ) -> dict:
        if not public_id:
            raise ValueError(
                "Cloudinary public ID is required."
            )

        result = cloudinary.uploader.destroy(
            public_id,
            resource_type="image",
            invalidate=True,
        )

        deletion_result = result.get(
            "result",
        )

        if deletion_result not in {
            "ok",
            "not found",
        }:
            raise RuntimeError(
                "Cloudinary image deletion failed: "
                f"{deletion_result}"
            )

        return result


cloudinary_service = CloudinaryService()