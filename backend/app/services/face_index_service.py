import json
import sqlite3
from pathlib import Path

import numpy as np


class FaceIndexService:
    def __init__(self):
        database_path = (
            Path(__file__).resolve().parents[2]
            / "face_index.db"
        )

        self.database_path = str(database_path)

        self._create_tables()

    # -------------------------------------------------
    # DATABASE CONNECTION
    # -------------------------------------------------

    def _connect(self):
        return sqlite3.connect(
            self.database_path,
        )

    # -------------------------------------------------
    # CREATE DATABASE TABLES
    # -------------------------------------------------

    def _create_tables(self):
        with self._connect() as connection:

            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS face_embeddings (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    room_id TEXT NOT NULL,
                    photo_id TEXT NOT NULL,
                    face_index INTEGER NOT NULL,
                    embedding TEXT NOT NULL,
                    detection_score REAL,
                    bbox TEXT
                )
                """
            )

            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS processed_photos (
                    room_id TEXT NOT NULL,
                    photo_id TEXT NOT NULL,
                    processed_at TIMESTAMP
                        DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (
                        room_id,
                        photo_id
                    )
                )
                """
            )

            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS image_embeddings (
                    room_id TEXT NOT NULL,
                    photo_id TEXT NOT NULL,
                    embedding TEXT NOT NULL,
                    created_at TIMESTAMP
                        DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (
                        room_id,
                        photo_id
                    )
                )
                """
            )

            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS photo_categories (
                    room_id TEXT NOT NULL,
                    photo_id TEXT NOT NULL,
                    category TEXT NOT NULL,
                    score REAL NOT NULL,
                    PRIMARY KEY (
                        room_id,
                        photo_id,
                        category
                    )
                )
                """
            )

            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS photo_hashes (
                    room_id TEXT NOT NULL,
                    photo_id TEXT NOT NULL,
                    phash TEXT NOT NULL,
                    PRIMARY KEY (
                        room_id,
                        photo_id
                    )
                )
                """
            )




            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS photo_quality (
                    room_id TEXT NOT NULL,
                    photo_id TEXT NOT NULL,
                    width INTEGER NOT NULL,
                    height INTEGER NOT NULL,
                    megapixels REAL NOT NULL,
                    sharpness REAL NOT NULL,
                    quality_score REAL NOT NULL,
                    PRIMARY KEY (
                        room_id,
                        photo_id
                    )
                )
                """
            )

            connection.commit()

    # -------------------------------------------------
    # SAVE PHOTO FACE EMBEDDINGS
    # -------------------------------------------------

    def save_photo_faces(
        self,
        room_id: str,
        photo_id: str,
        faces: list[dict],
    ):
        with self._connect() as connection:

            connection.execute(
                """
                DELETE FROM face_embeddings
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            for face in faces:
                connection.execute(
                    """
                    INSERT INTO face_embeddings (
                        room_id,
                        photo_id,
                        face_index,
                        embedding,
                        detection_score,
                        bbox
                    )
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        room_id,
                        photo_id,
                        face["face_index"],
                        json.dumps(
                            face["embedding"],
                        ),
                        face["detection_score"],
                        json.dumps(
                            face["bbox"],
                        ),
                    ),
                )

            # Mark as processed even if no faces
            # were detected.
            connection.execute(
                """
                INSERT INTO processed_photos (
                    room_id,
                    photo_id
                )
                VALUES (?, ?)
                ON CONFLICT (
                    room_id,
                    photo_id
                )
                DO UPDATE SET
                    processed_at = CURRENT_TIMESTAMP
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            connection.commit()

    # -------------------------------------------------
    # FIND MATCHING FACES
    # -------------------------------------------------

    def find_matching_photos(
        self,
        reference_embedding: list[float],
        room_ids: list[str],
        threshold: float = 0.45,
    ) -> list[dict]:

        if not room_ids:
            return []

        reference = np.asarray(
            reference_embedding,
            dtype=np.float32,
        )

        placeholders = ",".join(
            "?"
            for _ in room_ids
        )

        query = f"""
            SELECT
                room_id,
                photo_id,
                face_index,
                embedding
            FROM face_embeddings
            WHERE room_id IN ({placeholders})
        """

        with self._connect() as connection:
            rows = connection.execute(
                query,
                room_ids,
            ).fetchall()

        best_matches = {}

        for (
            room_id,
            photo_id,
            face_index,
            embedding_json,
        ) in rows:

            stored_embedding = np.asarray(
                json.loads(
                    embedding_json,
                ),
                dtype=np.float32,
            )

            similarity = float(
                np.dot(
                    reference,
                    stored_embedding,
                )
            )

            if similarity < threshold:
                continue

            key = (
                room_id,
                photo_id,
            )

            current_match = best_matches.get(
                key,
            )

            if (
                current_match is None
                or similarity
                > current_match["similarity"]
            ):
                best_matches[key] = {
                    "roomId": room_id,
                    "photoId": photo_id,
                    "faceIndex": face_index,
                    "similarity": similarity,
                }

        matches = list(
            best_matches.values(),
        )

        matches.sort(
            key=lambda item:
                item["similarity"],
            reverse=True,
        )

        return matches

    # -------------------------------------------------
    # GET FACE-PROCESSED PHOTO IDS
    # -------------------------------------------------

    def get_indexed_photo_ids(
        self,
        room_id: str,
    ) -> list[str]:

        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT photo_id
                FROM processed_photos
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            ).fetchall()

        return [
            row[0]
            for row in rows
        ]

    # -------------------------------------------------
    # SAVE IMAGE EMBEDDING
    # -------------------------------------------------

    def save_image_embedding(
        self,
        room_id: str,
        photo_id: str,
        embedding: list[float],
    ):

        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO image_embeddings (
                    room_id,
                    photo_id,
                    embedding
                )
                VALUES (?, ?, ?)
                ON CONFLICT (
                    room_id,
                    photo_id
                )
                DO UPDATE SET
                    embedding = excluded.embedding,
                    created_at = CURRENT_TIMESTAMP
                """,
                (
                    room_id,
                    photo_id,
                    json.dumps(
                        embedding,
                    ),
                ),
            )

            connection.commit()

    # -------------------------------------------------
    # SEMANTIC PHOTO SEARCH
    # -------------------------------------------------

    def find_semantic_matches(
        self,
        query_embedding: list[float],
        room_ids: list[str],
        limit: int = 50,
        minimum_similarity: float = 0.30,
    ) -> list[dict]:

        if not room_ids:
            return []

        query_vector = np.asarray(
            query_embedding,
            dtype=np.float32,
        )

        placeholders = ",".join(
            "?"
            for _ in room_ids
        )

        query = f"""
            SELECT
                room_id,
                photo_id,
                embedding
            FROM image_embeddings
            WHERE room_id IN ({placeholders})
        """

        with self._connect() as connection:
            rows = connection.execute(
                query,
                room_ids,
            ).fetchall()

        matches = []

        for (
            room_id,
            photo_id,
            embedding_json,
        ) in rows:

            image_vector = np.asarray(
                json.loads(
                    embedding_json,
                ),
                dtype=np.float32,
            )

            similarity = float(
                np.dot(
                    query_vector,
                    image_vector,
                )
            )

            print(
                f"{photo_id} -> {similarity:.4f}"
            )

            if similarity < minimum_similarity:
                continue

            matches.append({
                "roomId": room_id,
                "photoId": photo_id,
                "similarity": similarity,
            })

        matches.sort(
            key=lambda item:
                item["similarity"],
            reverse=True,
        )

        return matches[:limit]

    # -------------------------------------------------
    # GET SEMANTICALLY INDEXED PHOTO IDS
    # -------------------------------------------------

    def get_semantic_indexed_photo_ids(
        self,
        room_id: str,
    ) -> list[str]:

        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT photo_id
                FROM image_embeddings
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            ).fetchall()

        return [
            row[0]
            for row in rows
        ]

    # -------------------------------------------------
    # SAVE PHOTO CATEGORIES
    # -------------------------------------------------

    def save_photo_categories(
        self,
        room_id: str,
        photo_id: str,
        categories: list[dict],
    ):

        with self._connect() as connection:

            connection.execute(
                """
                DELETE FROM photo_categories
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            for item in categories:
                connection.execute(
                    """
                    INSERT INTO photo_categories (
                        room_id,
                        photo_id,
                        category,
                        score
                    )
                    VALUES (?, ?, ?, ?)
                    """,
                    (
                        room_id,
                        photo_id,
                        item["category"],
                        item["score"],
                    ),
                )

            connection.commit()

    # -------------------------------------------------
    # GET PHOTOS BY CATEGORY
    # -------------------------------------------------

    def get_photos_by_category(
        self,
        category: str,
        room_ids: list[str],
    ) -> list[dict]:

        if not room_ids:
            return []

        placeholders = ",".join(
            "?"
            for _ in room_ids
        )

        query = f"""
            SELECT
                room_id,
                photo_id,
                score
            FROM photo_categories
            WHERE category = ?
            AND room_id IN ({placeholders})
            ORDER BY score DESC
        """

        parameters = [
            category,
            *room_ids,
        ]

        with self._connect() as connection:
            rows = connection.execute(
                query,
                parameters,
            ).fetchall()

        return [
            {
                "roomId": room_id,
                "photoId": photo_id,
                "score": score,
            }
            for (
                room_id,
                photo_id,
                score,
            ) in rows
        ]

    # -------------------------------------------------
    # GET CATEGORIZED PHOTO IDS
    # -------------------------------------------------

    def get_categorized_photo_ids(
        self,
        room_id: str,
    ) -> list[str]:

        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT DISTINCT photo_id
                FROM photo_categories
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            ).fetchall()

        return [
            row[0]
            for row in rows
        ]

    # -------------------------------------------------
    # FIND VISUALLY SIMILAR PHOTOS
    # -------------------------------------------------

    def find_similar_photos(
        self,
        room_id: str,
        photo_id: str,
        allowed_room_ids: list[str],
        limit: int = 30,
        minimum_similarity: float = 0.0,
    ) -> list[dict]:

        if not allowed_room_ids:
            return []

        # IMPORTANT:
        # Your real table is image_embeddings.
        with self._connect() as connection:
            reference_row = connection.execute(
                """
                SELECT embedding
                FROM image_embeddings
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            ).fetchone()

        if reference_row is None:
            return []

        reference_embedding = np.asarray(
            json.loads(
                reference_row[0],
            ),
            dtype=np.float32,
        )

        placeholders = ",".join(
            "?"
            for _ in allowed_room_ids
        )

        query = f"""
            SELECT
                room_id,
                photo_id,
                embedding
            FROM image_embeddings
            WHERE room_id IN ({placeholders})
        """

        with self._connect() as connection:
            rows = connection.execute(
                query,
                allowed_room_ids,
            ).fetchall()

        matches = []

        for (
            candidate_room_id,
            candidate_photo_id,
            embedding_json,
        ) in rows:

            # Skip reference image itself.
            if (
                candidate_room_id == room_id
                and
                candidate_photo_id == photo_id
            ):
                continue

            candidate_embedding = np.asarray(
                json.loads(
                    embedding_json,
                ),
                dtype=np.float32,
            )

            similarity = float(
                np.dot(
                    reference_embedding,
                    candidate_embedding,
                )
            )

            if similarity < minimum_similarity:
                continue

            matches.append({
                "roomId":
                    candidate_room_id,
                "photoId":
                    candidate_photo_id,
                "similarity":
                    similarity,
            })

        matches.sort(
            key=lambda item:
                item["similarity"],
            reverse=True,
        )

        return matches[:limit]

    # -------------------------------------------------
    # SAVE PHOTO PHASH
    # -------------------------------------------------

    def save_photo_hash(
        self,
        room_id: str,
        photo_id: str,
        phash: str,
    ):

        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO photo_hashes (
                    room_id,
                    photo_id,
                    phash
                )
                VALUES (?, ?, ?)
                ON CONFLICT (
                    room_id,
                    photo_id
                )
                DO UPDATE SET
                    phash = excluded.phash
                """,
                (
                    room_id,
                    photo_id,
                    phash,
                ),
            )

            connection.commit()

    # -------------------------------------------------
    # GET ONE PHOTO PHASH
    # -------------------------------------------------

    def get_photo_hash(
        self,
        room_id: str,
        photo_id: str,
    ) -> str | None:

        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT phash
                FROM photo_hashes
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            ).fetchone()

        if row is None:
            return None

        return row[0]

    # -------------------------------------------------
    # GET HASHES FROM ACCESSIBLE ROOMS
    # -------------------------------------------------

    def get_photo_hashes(
        self,
        room_ids: list[str],
    ) -> list[dict]:

        if not room_ids:
            return []

        placeholders = ",".join(
            "?"
            for _ in room_ids
        )

        query = f"""
            SELECT
                room_id,
                photo_id,
                phash
            FROM photo_hashes
            WHERE room_id IN ({placeholders})
        """

        with self._connect() as connection:
            rows = connection.execute(
                query,
                room_ids,
            ).fetchall()

        return [
            {
                "roomId": room_id,
                "photoId": photo_id,
                "phash": phash,
            }
            for (
                room_id,
                photo_id,
                phash,
            ) in rows
        ]


    # -------------------------------------------------
    # GET HASHES WITH QUALITY DATA
    # -------------------------------------------------

    def get_photo_hashes_with_quality(
        self,
        room_ids: list[str],
    ) -> list[dict]:

        if not room_ids:
            return []

        placeholders = ",".join(
            "?"
            for _ in room_ids
        )

        query = f"""
            SELECT
                h.room_id,
                h.photo_id,
                h.phash,
                q.width,
                q.height,
                q.megapixels,
                q.sharpness,
                q.quality_score
            FROM photo_hashes h
            LEFT JOIN photo_quality q
                ON h.room_id = q.room_id
                AND h.photo_id = q.photo_id
            WHERE h.room_id IN ({placeholders})
        """

        with self._connect() as connection:
            rows = connection.execute(
                query,
                room_ids,
            ).fetchall()

        photos = []

        for row in rows:
            (
                room_id,
                photo_id,
                phash,
                width,
                height,
                megapixels,
                sharpness,
                quality_score,
            ) = row

            photos.append({
                "roomId": room_id,
                "photoId": photo_id,
                "phash": phash,
                "width": width,
                "height": height,
                "megapixels": megapixels,
                "sharpness": sharpness,
                "qualityScore": quality_score,
            })

        return photos



    # -------------------------------------------------
    # GET HASHED PHOTO IDS
    # -------------------------------------------------

    def get_hashed_photo_ids(
        self,
        room_id: str,
    ) -> list[str]:

        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT photo_id
                FROM photo_hashes
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            ).fetchall()

        return [
            row[0]
            for row in rows
        ]
    

    # -------------------------------------------------
    # SAVE PHOTO QUALITY
    # -------------------------------------------------

    def save_photo_quality(
        self,
        room_id: str,
        photo_id: str,
        quality: dict,
    ):
        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO photo_quality (
                    room_id,
                    photo_id,
                    width,
                    height,
                    megapixels,
                    sharpness,
                    quality_score
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (
                    room_id,
                    photo_id
                )
                DO UPDATE SET
                    width = excluded.width,
                    height = excluded.height,
                    megapixels = excluded.megapixels,
                    sharpness = excluded.sharpness,
                    quality_score = excluded.quality_score
                """,
                (
                    room_id,
                    photo_id,
                    quality["width"],
                    quality["height"],
                    quality["megapixels"],
                    quality["sharpness"],
                    quality["qualityScore"],
                ),
            )

            connection.commit()




    # -------------------------------------------------
    # GET PHOTO QUALITY
    # -------------------------------------------------

    def get_photo_quality(
        self,
        room_id: str,
        photo_id: str,
    ) -> dict | None:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT
                    width,
                    height,
                    megapixels,
                    sharpness,
                    quality_score
                FROM photo_quality
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            ).fetchone()

        if row is None:
            return None

        return {
            "width": row[0],
            "height": row[1],
            "megapixels": row[2],
            "sharpness": row[3],
            "qualityScore": row[4],
        }       





    # -------------------------------------------------
    # DELETE ONE PHOTO FROM AI INDEX
    # -------------------------------------------------

    def delete_photo_faces(
        self,
        room_id: str,
        photo_id: str,
    ):

        with self._connect() as connection:

            connection.execute(
                """
                DELETE FROM face_embeddings
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM processed_photos
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM image_embeddings
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM photo_categories
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM photo_hashes
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )


            connection.execute(
                """
                DELETE FROM photo_quality
                WHERE room_id = ?
                AND photo_id = ?
                """,
                (
                    room_id,
                    photo_id,
                ),
            )

            connection.commit()

    # -------------------------------------------------
    # DELETE ENTIRE ROOM FROM AI INDEX
    # -------------------------------------------------

    def delete_room_faces(
        self,
        room_id: str,
    ):

        with self._connect() as connection:

            connection.execute(
                """
                DELETE FROM face_embeddings
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM processed_photos
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM image_embeddings
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM photo_categories
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM photo_hashes
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            )

            connection.execute(
                """
                DELETE FROM photo_quality
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            )

            connection.commit()



    # -------------------------------------------------
    # GET QUALITY-INDEXED PHOTO IDS
    # -------------------------------------------------

    def get_quality_indexed_photo_ids(
        self,
        room_id: str,
    ) -> list[str]:

        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT photo_id
                FROM photo_quality
                WHERE room_id = ?
                """,
                (
                    room_id,
                ),
            ).fetchall()

        return [
            row[0]
            for row in rows
        ]


face_index_service = FaceIndexService()