from io import BytesIO

import cv2
import numpy as np
from insightface.app import FaceAnalysis
from PIL import Image


class FaceService:
    def __init__(self):
        self.face_app = FaceAnalysis(
            name="buffalo_l",
            providers=["CPUExecutionProvider"],
        )

        self.face_app.prepare(
            ctx_id=-1,
            det_size=(640, 640),
        )

    # -------------------------------------------------
    # REFERENCE SELFIE
    # -------------------------------------------------

    def analyze_reference_selfie(
        self,
        image_bytes: bytes,
    ) -> dict:
        pil_image = Image.open(
            BytesIO(image_bytes),
        ).convert("RGB")

        rgb_image = np.array(
            pil_image,
        )

        bgr_image = cv2.cvtColor(
            rgb_image,
            cv2.COLOR_RGB2BGR,
        )

        faces = self.face_app.get(
            bgr_image,
        )

        # No face found
        if len(faces) == 0:
            raise ValueError(
                "No face detected. "
                "Please choose a clear selfie."
            )

        # Sort faces from largest to smallest
        faces = sorted(
            faces,
            key=lambda detected_face: (
                (
                    detected_face.bbox[2]
                    - detected_face.bbox[0]
                )
                * (
                    detected_face.bbox[3]
                    - detected_face.bbox[1]
                )
            ),
            reverse=True,
        )

        # Largest face is considered
        # the reference person
        face = faces[0]

        # If another face is almost as large as
        # the main face, the selfie is ambiguous
        if len(faces) > 1:
            main_area = (
                (
                    faces[0].bbox[2]
                    - faces[0].bbox[0]
                )
                * (
                    faces[0].bbox[3]
                    - faces[0].bbox[1]
                )
            )

            second_area = (
                (
                    faces[1].bbox[2]
                    - faces[1].bbox[0]
                )
                * (
                    faces[1].bbox[3]
                    - faces[1].bbox[1]
                )
            )

            if (
                main_area > 0
                and second_area / main_area > 0.65
            ):
                raise ValueError(
                    "Multiple prominent faces detected. "
                    "Please choose a clearer "
                    "reference selfie."
                )

        # Generate embedding for selected face
        embedding = face.normed_embedding

        if embedding is None:
            raise ValueError(
                "Unable to create face embedding."
            )

        return {
            "face_count": 1,
            "embedding": embedding.tolist(),
            "embedding_size": len(
                embedding,
            ),
            "detection_score": float(
                face.det_score,
            ),
        }

    # -------------------------------------------------
    # ROOM PHOTO
    # -------------------------------------------------

    def analyze_room_photo(
        self,
        image_bytes: bytes,
    ) -> list[dict]:
        pil_image = Image.open(
            BytesIO(image_bytes),
        ).convert("RGB")

        rgb_image = np.array(
            pil_image,
        )

        bgr_image = cv2.cvtColor(
            rgb_image,
            cv2.COLOR_RGB2BGR,
        )

        faces = self.face_app.get(
            bgr_image,
        )

        results = []

        for index, face in enumerate(
            faces,
        ):
            embedding = face.normed_embedding

            if embedding is None:
                continue

            bbox = face.bbox.astype(
                int,
            ).tolist()

            results.append({
                "face_index": index,
                "embedding": (
                    embedding.tolist()
                ),
                "embedding_size": len(
                    embedding,
                ),
                "detection_score": float(
                    face.det_score,
                ),
                "bbox": bbox,
            })

        return results


face_service = FaceService()