from io import BytesIO

import httpx
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel
from app.services.clip_service import clip_service

from app.services.face_index_service import face_index_service
from app.services.face_service import face_service
from app.services.cloudinary_service import (
    cloudinary_service,
)
from app.services.caption_service import caption_service

from app.services.duplicate_service import (
    duplicate_service,
)


from app.services.image_quality_service import (
    image_quality_service,
)

app = FastAPI(
    title="SnapSync AI Backend",
    version="1.0.0",
)
class DeleteRoomAssetsRequest(BaseModel):
    public_ids: list[str]


# -------------------------------------------------
# ROOT
# -------------------------------------------------

@app.get("/")
def root():
    return {
        "message": "SnapSync AI backend is running",
    }


# -------------------------------------------------
# HEALTH CHECK
# -------------------------------------------------

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "snapsync-ai-backend",
    }


# -------------------------------------------------
# REFERENCE SELFIE + FACE SEARCH
# -------------------------------------------------

@app.post("/api/v1/face/reference")
async def upload_reference_selfie(
    room_ids: str,
    selfie: UploadFile = File(...),
):
    image_bytes = await selfie.read()

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="Uploaded image is empty.",
        )

    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=(
                "Image is too large. "
                "Maximum size is 10 MB."
            ),
        )

    # Validate image
    try:
        image = Image.open(
            BytesIO(image_bytes),
        )

        image.verify()

        # Reopen after verify()
        image = Image.open(
            BytesIO(image_bytes),
        )

        width, height = image.size
        image_format = image.format

    except UnidentifiedImageError:
        raise HTTPException(
            status_code=400,
            detail=(
                "The uploaded file is not "
                "a valid image."
            ),
        )

    except Exception as error:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unable to process image: {error}"
            ),
        )

    allowed_formats = {
        "JPEG",
        "PNG",
        "WEBP",
        "HEIF",
        "HEIC",
    }

    if image_format not in allowed_formats:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unsupported image format: "
                f"{image_format}"
            ),
        )

    # Detect reference face and generate embedding
    try:
        face_result = (
            face_service.analyze_reference_selfie(
                image_bytes,
            )
        )

    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        )

    # Convert comma-separated room IDs to list
    allowed_room_ids = [
        room_id.strip()
        for room_id in room_ids.split(",")
        if room_id.strip()
    ]

    if not allowed_room_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "At least one room ID is required "
                "for face search."
            ),
        )

    # Match reference face against indexed room faces
    matches = (
        face_index_service.find_matching_photos(
            reference_embedding=(
                face_result["embedding"]
            ),
            room_ids=allowed_room_ids,
        )
    )

    return {
        "status": "accepted",
        "message": (
            "Face search completed successfully."
        ),
        "filename": selfie.filename,
        "width": width,
        "height": height,
        "format": image_format,
        "faceCount": (
            face_result["face_count"]
        ),
        "embeddingSize": (
            face_result["embedding_size"]
        ),
        "detectionScore": (
            face_result["detection_score"]
        ),
        "matchCount": len(matches),
        "matches": matches,
        "nextStep": "show_results",
    }


# -------------------------------------------------
# PROCESS ROOM PHOTO
# -------------------------------------------------

@app.post("/api/v1/photos/process")
async def process_room_photo(
    room_id: str,
    photo_id: str,
    image_url: str,
):
    # -------------------------------------------------
    # DOWNLOAD IMAGE
    # -------------------------------------------------

    try:
        async with httpx.AsyncClient(
            timeout=30.0,
            follow_redirects=True,
        ) as client:
            response = await client.get(
                image_url,
            )

            response.raise_for_status()

            image_bytes = response.content

    except Exception as error:
        raise HTTPException(
            status_code=400,
            detail=(
                "Unable to download photo: "
                f"{error}"
            ),
        )


    # -------------------------------------------------
    # VALIDATE IMAGE DATA
    # -------------------------------------------------

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="Downloaded photo is empty.",
        )

    if len(image_bytes) > 20 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail=(
                "Room photo is too large. "
                "Maximum size is 20 MB."
            ),
        )
    


    # -------------------------------------------------
    # PERCEPTUAL HASH
    # -------------------------------------------------

    try:
        photo_hash = (
            duplicate_service.create_phash(
                image_bytes,
            )
        )

        face_index_service.save_photo_hash(
            room_id=room_id,
            photo_id=photo_id,
            phash=photo_hash,
        )

    except Exception as error:
        print(
            "pHash generation failed for "
            f"{photo_id}: {error}"
        )


    # -------------------------------------------------
    # IMAGE QUALITY ANALYSIS
    # -------------------------------------------------

    try:
        quality = (
            image_quality_service.calculate_quality(
                image_bytes,
            )
        )

        face_index_service.save_photo_quality(
            room_id=room_id,
            photo_id=photo_id,
            quality=quality,
        )

    except Exception as error:
        print(
            "Image quality analysis failed for "
            f"{photo_id}: {error}"
        )

        quality = None





    # -------------------------------------------------
    # FACE PROCESSING
    # -------------------------------------------------

    try:
        faces = (
            face_service.analyze_room_photo(
                image_bytes,
            )
        )

        face_index_service.save_photo_faces(
            room_id=room_id,
            photo_id=photo_id,
            faces=faces,
        )

    except Exception as error:
        raise HTTPException(
            status_code=400,
            detail=(
                "Unable to process photo faces: "
                f"{error}"
            ),
        )


    # -------------------------------------------------
    # CLIP SEMANTIC EMBEDDING
    # -------------------------------------------------

    try:
        image_embedding = (
            clip_service.create_image_embedding(
                image_bytes,
            )
        )

        face_index_service.save_image_embedding(
            room_id=room_id,
            photo_id=photo_id,
            embedding=image_embedding,
        )

    except Exception as error:
        raise HTTPException(
            status_code=400,
            detail=(
                "Unable to create semantic "
                "embedding: "
                f"{error}"
            ),
        )
    

    # -------------------------------------------------
    # MULTI-CATEGORY PHOTO CLASSIFICATION
    # -------------------------------------------------

    try:
        categories = []

        # Add People when at least one face
        # was detected by InsightFace.
        if len(faces) > 0:
            categories.append(
                {
                    "category": "people",
                    "score": 1.0,
                }
            )

        # Always run CLIP classification,
        # even when people are present.
        clip_categories = (
            clip_service.classify_categories(
                image_embedding=image_embedding,
                minimum_score=0.20,
            )
        )

        categories.extend(
            clip_categories,
        )

        # Save all matching categories.
        face_index_service.save_photo_categories(
            room_id=room_id,
            photo_id=photo_id,
            categories=categories,
        )

    except Exception as error:
        print(
            "Category classification failed for "
            f"{photo_id}: {error}"
        )

        categories = []
    
    # -------------------------------------------------
    # AI CAPTION GENERATION
    # -------------------------------------------------

    try:
        caption = caption_service.generate_caption(
            image_bytes,
        )

    except Exception as error:
        # Caption failure should not destroy successful
        # face and semantic indexing.
        print(
            "Caption generation failed for "
            f"{photo_id}: {error}"
        )

        caption = None


    # -------------------------------------------------
    # RESPONSE
    # -------------------------------------------------

    return {
        "status": "processed",
        "roomId": room_id,
        "photoId": photo_id,
        "faceCount": len(faces),
        "semanticIndexed": True,
        "categories": categories,
        "caption": caption,
        "quality": quality,
        "message": (
            "Photo processed successfully. "
            f"{len(faces)} face(s) detected, "
            "semantic embedding created, "
            "category classification attempted, "
            "and caption generation attempted."
        ),
    }

# -------------------------------------------------
# SEMANTIC PHOTO SEARCH
# -------------------------------------------------

@app.get("/api/v1/photos/search")
async def search_photos(
    query: str,
    room_ids: str,
    limit: int = 50,
):
    cleaned_query = query.strip()

    if not cleaned_query:
        raise HTTPException(
            status_code=400,
            detail="Search query cannot be empty.",
        )

    allowed_room_ids = [
        room_id.strip()
        for room_id in room_ids.split(",")
        if room_id.strip()
    ]

    if not allowed_room_ids:
        raise HTTPException(
            status_code=400,
            detail="At least one room ID is required.",
        )

    if limit < 1 or limit > 100:
        raise HTTPException(
            status_code=400,
            detail=(
                "Limit must be between 1 and 100."
            ),
        )

    try:
        query_embedding = (
            clip_service.create_text_embedding(
                cleaned_query,
            )
        )

        matches = (
            face_index_service.find_semantic_matches(
                query_embedding=query_embedding,
                room_ids=allowed_room_ids,
                limit=limit,
                minimum_similarity=0.0,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Semantic search failed: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "query": cleaned_query,
        "matchCount": len(matches),
        "matches": matches,
    }


# -------------------------------------------------
# GET PHOTOS BY CATEGORY
# -------------------------------------------------

@app.get("/api/v1/photos/category")
async def get_category_photos(
    category: str,
    room_ids: str,
):
    allowed_categories = {
        "people",
        "nature",
        "food",
        "documents",
        "animals",
        "vehicles",
    }

    cleaned_category = (
        category.strip().lower()
    )

    if cleaned_category not in allowed_categories:
        raise HTTPException(
            status_code=400,
            detail="Invalid photo category.",
        )

    allowed_room_ids = [
        room_id.strip()
        for room_id in room_ids.split(",")
        if room_id.strip()
    ]

    if not allowed_room_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "At least one room ID is required."
            ),
        )

    try:
        matches = (
            face_index_service
            .get_photos_by_category(
                category=cleaned_category,
                room_ids=allowed_room_ids,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to load category photos: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "category": cleaned_category,
        "matchCount": len(matches),
        "matches": matches,
    }


# -------------------------------------------------
# GET PHASHED PHOTO IDS
# -------------------------------------------------

@app.get("/api/v1/photos/hashed")
async def get_hashed_photos(
    room_id: str,
):
    try:
        photo_ids = (
            face_index_service
            .get_hashed_photo_ids(
                room_id=room_id,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to read photo hash status: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "roomId": room_id,
        "photoIds": photo_ids,
        "count": len(photo_ids),
    }


# -------------------------------------------------
# BACKFILL PHOTO QUALITY
# -------------------------------------------------

@app.post("/api/v1/photos/quality")
async def process_photo_quality(
    room_id: str,
    photo_id: str,
    image_url: str,
):
    try:
        existing_quality = (
            face_index_service.get_photo_quality(
                room_id=room_id,
                photo_id=photo_id,
            )
        )

        if existing_quality is not None:
            return {
                "status": "already_processed",
                "roomId": room_id,
                "photoId": photo_id,
                "quality": existing_quality,
            }

        async with httpx.AsyncClient(
            timeout=30.0,
            follow_redirects=True,
        ) as client:
            response = await client.get(
                image_url,
            )

            response.raise_for_status()

            image_bytes = response.content

        if not image_bytes:
            raise HTTPException(
                status_code=400,
                detail="Downloaded photo is empty.",
            )

        quality = (
            image_quality_service.calculate_quality(
                image_bytes,
            )
        )

        face_index_service.save_photo_quality(
            room_id=room_id,
            photo_id=photo_id,
            quality=quality,
        )

        return {
            "status": "processed",
            "roomId": room_id,
            "photoId": photo_id,
            "quality": quality,
        }

    except HTTPException:
        raise

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to process photo quality: "
                f"{error}"
            ),
        )


# -------------------------------------------------
# GET QUALITY-PROCESSED PHOTO IDS
# -------------------------------------------------

@app.get("/api/v1/photos/quality-indexed")
async def get_quality_indexed_photos(
    room_id: str,
):
    try:
        photo_ids = (
            face_index_service
            .get_quality_indexed_photo_ids(
                room_id=room_id,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to read quality status: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "roomId": room_id,
        "photoIds": photo_ids,
        "count": len(photo_ids),
    }



# -------------------------------------------------
# FIND SIMILAR PHOTOS
# -------------------------------------------------

@app.get("/api/v1/photos/similar")
async def get_similar_photos(
    room_id: str,
    photo_id: str,
    room_ids: str,
    limit: int = 30,
):
    allowed_room_ids = [
        current_room_id.strip()
        for current_room_id in room_ids.split(",")
        if current_room_id.strip()
    ]

    if not allowed_room_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "At least one accessible room ID "
                "is required."
            ),
        )

    # The reference photo must belong to one of
    # the rooms accessible to the user.
    if room_id not in allowed_room_ids:
        raise HTTPException(
            status_code=403,
            detail=(
                "Reference photo room is not "
                "in the accessible room list."
            ),
        )

    if limit < 1:
        raise HTTPException(
            status_code=400,
            detail="Limit must be at least 1.",
        )

    safe_limit = min(
        limit,
        100,
    )

    try:
        matches = (
            face_index_service
            .find_similar_photos(
                room_id=room_id,
                photo_id=photo_id,
                allowed_room_ids=allowed_room_ids,
                limit=safe_limit,
                minimum_similarity=0.60,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to find similar photos: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "reference": {
            "roomId": room_id,
            "photoId": photo_id,
        },
        "minimumSimilarity": 0.60,
        "matchCount": len(matches),
        "matches": matches,
    }


# -------------------------------------------------
# FIND NEAR-DUPLICATE PHOTOS
# -------------------------------------------------

# -------------------------------------------------
# FIND NEAR-DUPLICATE PHOTOS
# -------------------------------------------------

@app.get("/api/v1/photos/duplicates")
async def get_duplicate_photos(
    room_id: str,
    photo_id: str,
    room_ids: str,
    limit: int = 30,
):
    allowed_room_ids = [
        current_room_id.strip()
        for current_room_id
        in room_ids.split(",")
        if current_room_id.strip()
    ]

    if not allowed_room_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "At least one accessible "
                "room ID is required."
            ),
        )

    if room_id not in allowed_room_ids:
        raise HTTPException(
            status_code=403,
            detail=(
                "Reference photo room is not "
                "in the accessible room list."
            ),
        )

    if limit < 1:
        raise HTTPException(
            status_code=400,
            detail="Limit must be at least 1.",
        )

    safe_limit = min(
        limit,
        100,
    )

    try:
        # Get the reference photo pHash.
        reference_hash = (
            face_index_service.get_photo_hash(
                room_id=room_id,
                photo_id=photo_id,
            )
        )

        if reference_hash is None:
            raise HTTPException(
                status_code=404,
                detail=(
                    "Reference photo has not been "
                    "processed for duplicate detection."
                ),
            )

        # Get hashes from every accessible room.
        candidate_photos = (
            face_index_service.get_photo_hashes(
                room_ids=allowed_room_ids,
            )
        )

        matches = []

        for candidate in candidate_photos:
            candidate_room_id = candidate[
                "roomId"
            ]

            candidate_photo_id = candidate[
                "photoId"
            ]

            candidate_hash = candidate[
                "phash"
            ]

            # Skip the reference photo itself.
            if (
                candidate_room_id == room_id
                and
                candidate_photo_id == photo_id
            ):
                continue

            distance = (
                duplicate_service.hash_distance(
                    reference_hash,
                    candidate_hash,
                )
            )

            # Lower pHash distance means
            # the images are more similar.
            if distance > 8:
                continue

            # Convert distance into a UI-friendly
            # similarity value.
            similarity = max(
                0.0,
                1.0 - (distance / 64.0),
            )

            matches.append({
                "roomId":
                    candidate_room_id,
                "photoId":
                    candidate_photo_id,
                "similarity":
                    similarity,
                "hashDistance":
                    distance,
            })

        matches.sort(
            key=lambda item:
                item["hashDistance"],
        )

        matches = matches[
            :safe_limit
        ]

    except HTTPException:
        raise

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to find duplicate "
                f"photos: {error}"
            ),
        )

    return {
        "status": "success",
        "reference": {
            "roomId": room_id,
            "photoId": photo_id,
        },
        "maximumHashDistance": 8,
        "matchCount": len(matches),
        "matches": matches,
    }


# -------------------------------------------------
# GET AUTOMATIC DUPLICATE GROUPS
# -------------------------------------------------

@app.get("/api/v1/photos/duplicate-groups")
async def get_duplicate_groups(
    room_ids: str,
):
    allowed_room_ids = [
        room_id.strip()
        for room_id in room_ids.split(",")
        if room_id.strip()
    ]

    if not allowed_room_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "At least one accessible "
                "room ID is required."
            ),
        )

    try:
        photos = (
            face_index_service
            .get_photo_hashes_with_quality(
                room_ids=allowed_room_ids,
            )
        )

        groups = (
            duplicate_service.group_duplicates(
                photos=photos,
                maximum_distance=8,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to create duplicate "
                f"groups: {error}"
            ),
        )

    return {
        "status": "success",
        "groupCount": len(groups),
        "groups": groups,
    }



# -------------------------------------------------
# DELETE PHOTO FROM AI INDEX
# -------------------------------------------------

# -------------------------------------------------
# DELETE PHOTO FROM CLOUDINARY AND AI INDEX
# -------------------------------------------------

@app.delete("/api/v1/photos/index")
async def delete_photo_index(
    room_id: str,
    photo_id: str,
    public_id: str,
):
    try:
        # Delete actual image from Cloudinary
        cloudinary_service.delete_image(
            public_id=public_id,
        )

        # Delete all AI index data
        face_index_service.delete_photo_faces(
            room_id=room_id,
            photo_id=photo_id,
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to delete photo: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "roomId": room_id,
        "photoId": photo_id,
        "message": (
            "Photo removed from Cloudinary "
            "and AI indexes."
        ),
    }








# -------------------------------------------------
# DELETE ENTIRE ROOM FROM FACE INDEX
# -------------------------------------------------

# -------------------------------------------------
# DELETE ROOM ASSETS + AI INDEX
# -------------------------------------------------

@app.post(
    "/api/v1/rooms/delete-assets"
)
async def delete_room_assets(
    room_id: str,
    request: DeleteRoomAssetsRequest,
):
    deleted_assets = 0

    # ---------------------------------------------
    # 1. DELETE CLOUDINARY ASSETS
    # ---------------------------------------------

    try:
        for public_id in request.public_ids:
            if not public_id:
                continue

            cloudinary_service.delete_image(
                public_id=public_id,
            )

            deleted_assets += 1

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to delete all room assets. "
                f"{deleted_assets} asset(s) deleted "
                f"before failure: {error}"
            ),
        )

    # ---------------------------------------------
    # 2. DELETE ROOM AI INDEX
    # ---------------------------------------------

    try:
        face_index_service.delete_room_faces(
            room_id=room_id,
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Room images were deleted, but "
                "AI index cleanup failed: "
                f"{error}"
            ),
        )

    return {
        "status": "deleted",
        "roomId": room_id,
        "deletedAssetCount": deleted_assets,
        "message": (
            "Room assets and AI index "
            "deleted successfully."
        ),
    }
# -------------------------------------------------
# GET INDEXED PHOTO IDS FOR A ROOM
# -------------------------------------------------

@app.get("/api/v1/rooms/indexed-photos")
async def get_indexed_photos(
    room_id: str,
):
    try:
        photo_ids = (
            face_index_service.get_indexed_photo_ids(
                room_id=room_id,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to read room face index: "
                f"{error}"
            ),
        )

    return {
        "roomId": room_id,
        "photoIds": photo_ids,
        "count": len(photo_ids),
    }
# -------------------------------------------------
# DELETE PHOTO ASSET + AI INDEX
# -------------------------------------------------

@app.delete(
    "/api/v1/photos"
)
async def delete_photo(
    room_id: str,
    photo_id: str,
    public_id: str,
):
    if not room_id:
        raise HTTPException(
            status_code=400,
            detail="Room ID is required.",
        )

    if not photo_id:
        raise HTTPException(
            status_code=400,
            detail="Photo ID is required.",
        )

    if not public_id:
        raise HTTPException(
            status_code=400,
            detail="Cloudinary public ID is required.",
        )

    # ---------------------------------------------
    # 1. DELETE CLOUDINARY IMAGE
    # ---------------------------------------------

    try:
        cloudinary_service.delete_image(
            public_id=public_id,
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to delete image asset: "
                f"{error}"
            ),
        )

    # ---------------------------------------------
    # 2. DELETE AI FACE INDEX
    # ---------------------------------------------

    try:
        face_index_service.delete_photo_faces(
            room_id=room_id,
            photo_id=photo_id,
        )

    except Exception as error:
        # The Cloudinary image is already deleted
        # at this point. Report the partial failure.
        raise HTTPException(
            status_code=500,
            detail=(
                "Image deleted, but AI index "
                "cleanup failed: "
                f"{error}"
            ),
        )

    return {
        "status": "deleted",
        "roomId": room_id,
        "photoId": photo_id,
        "message": (
            "Photo asset and AI index "
            "deleted successfully."
        ),
    }

# -------------------------------------------------
# GET SEMANTICALLY INDEXED PHOTO IDS
# -------------------------------------------------

@app.get(
    "/api/v1/photos/semantic-indexed"
)
async def get_semantic_indexed_photos(
    room_id: str,
):
    try:
        photo_ids = (
            face_index_service
            .get_semantic_indexed_photo_ids(
                room_id=room_id,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to read semantic index: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "roomId": room_id,
        "photoIds": photo_ids,
        "count": len(photo_ids),
    }

# -------------------------------------------------
# GET CATEGORIZED PHOTO IDS
# -------------------------------------------------

@app.get(
    "/api/v1/photos/categorized"
)
async def get_categorized_photos(
    room_id: str,
):
    try:
        photo_ids = (
            face_index_service
            .get_categorized_photo_ids(
                room_id=room_id,
            )
        )

    except Exception as error:
        raise HTTPException(
            status_code=500,
            detail=(
                "Unable to read category status: "
                f"{error}"
            ),
        )

    return {
        "status": "success",
        "roomId": room_id,
        "photoIds": photo_ids,
        "count": len(photo_ids),
    }