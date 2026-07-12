from io import BytesIO

import imagehash
from PIL import Image


class DuplicateService:
    # ---------------------------------------------
    # CREATE PERCEPTUAL HASH
    # ---------------------------------------------

    def create_phash(
        self,
        image_bytes: bytes,
    ) -> str:
        image = Image.open(
            BytesIO(image_bytes),
        ).convert("RGB")

        photo_hash = imagehash.phash(
            image,
        )

        return str(photo_hash)

    # ---------------------------------------------
    # CALCULATE HASH DISTANCE
    # ---------------------------------------------

    def hash_distance(
        self,
        hash1: str,
        hash2: str,
    ) -> int:
        first_hash = imagehash.hex_to_hash(
            hash1,
        )

        second_hash = imagehash.hex_to_hash(
            hash2,
        )

        distance = (
            first_hash - second_hash
        )

        # Convert NumPy integer to normal Python int
        # so FastAPI can serialize it to JSON.
        return int(distance)

    # ---------------------------------------------
    # CHECK NEAR DUPLICATE
    # ---------------------------------------------

    def is_near_duplicate(
        self,
        hash1: str,
        hash2: str,
        maximum_distance: int = 8,
    ) -> bool:
        distance = self.hash_distance(
            hash1,
            hash2,
        )

        return distance <= maximum_distance




    # ---------------------------------------------
    # GROUP NEAR-DUPLICATE PHOTOS
    # ---------------------------------------------

    # ---------------------------------------------
    # GROUP NEAR-DUPLICATE PHOTOS
    # ---------------------------------------------

    # ---------------------------------------------
    # GROUP NEAR-DUPLICATE PHOTOS
    # ---------------------------------------------

    def group_duplicates(
        self,
        photos: list[dict],
        maximum_distance: int = 8,
    ) -> list[list[dict]]:
        if len(photos) < 2:
            return []

        photo_count = len(photos)

        # Build adjacency list.
        graph = {
            index: []
            for index in range(photo_count)
        }

        distances = {}

        # Compare every unique pair once.
        for first_index in range(photo_count):
            for second_index in range(
                first_index + 1,
                photo_count,
            ):
                first_photo = photos[first_index]
                second_photo = photos[second_index]

                distance = self.hash_distance(
                    first_photo["phash"],
                    second_photo["phash"],
                )

                if distance <= maximum_distance:
                    graph[first_index].append(
                        second_index,
                    )

                    graph[second_index].append(
                        first_index,
                    )

                    distances[
                        (
                            first_index,
                            second_index,
                        )
                    ] = distance

                    distances[
                        (
                            second_index,
                            first_index,
                        )
                    ] = distance

        visited = set()

        groups = []

        # Find connected components.
        for start_index in range(photo_count):
            if start_index in visited:
                continue

            stack = [
                start_index,
            ]

            component = []

            visited.add(
                start_index,
            )

            while stack:
                current_index = stack.pop()

                component.append(
                    current_index,
                )

                for neighbour_index in graph[
                    current_index
                ]:
                    if neighbour_index in visited:
                        continue

                    visited.add(
                        neighbour_index,
                    )

                    stack.append(
                        neighbour_index,
                    )

            # Ignore photos with no duplicate.
            if len(component) < 2:
                continue

            reference_index = component[0]

            group = []

            for photo_index in component:
                photo = photos[photo_index]

                if photo_index == reference_index:
                    distance = 0
                else:
                    # Direct distance from the
                    # displayed reference photo.
                    distance = self.hash_distance(
                        photos[reference_index][
                            "phash"
                        ],
                        photo["phash"],
                    )

                group.append({
                    **photo,
                    "hashDistance": int(
                        distance,
                    ),
                })

            # Find the highest-quality photo in this group.
            #
            # Older photos may not have a quality score yet,
            # so None is treated as 0.
            best_photo = max(
                group,
                key=lambda item:
                    item.get("qualityScore") or 0.0,
            )

            best_key = (
                best_photo["roomId"],
                best_photo["photoId"],
            )

            for item in group:
                item_key = (
                    item["roomId"],
                    item["photoId"],
                )

                item["recommendedKeep"] = (
                    item_key == best_key
                )

            # Put the recommended photo first.
            group.sort(
                key=lambda item: (
                    not item["recommendedKeep"],
                    item["hashDistance"],
                ),
            )

            groups.append(
                group,
            )
        # Larger groups first.
        groups.sort(
            key=len,
            reverse=True,
        )

        return groups  


duplicate_service = DuplicateService()