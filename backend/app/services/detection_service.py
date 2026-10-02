"""Run person detection for a session and persist Detection rows."""
from sqlalchemy.orm import Session

from app import models
from app.cv.detector import HOGPersonDetector


def run_detection(db: Session, session: models.AttendanceSession, image_path: str) -> dict:
    """Detect people in the session image, persist rows, update the session.

    Returns {"detections": [...], "count": n} where each detection dict has
    id, detection_number, x, y, width, height, confidence.
    """
    detector = HOGPersonDetector()
    raw = detector.detect(image_path)

    # Replace any previous detections for a clean re-run.
    db.query(models.Detection).filter(
        models.Detection.session_id == session.id
    ).delete()

    rows: list[models.Detection] = []
    for i, d in enumerate(raw, start=1):
        rows.append(
            models.Detection(
                session_id=session.id,
                detection_number=i,
                x=d["x"],
                y=d["y"],
                width=d["width"],
                height=d["height"],
                confidence=d["confidence"],
            )
        )
    db.add_all(rows)
    session.detected_count = len(rows)
    db.flush()  # populate ids

    return {
        "detections": [
            {
                "id": r.id,
                "detection_number": r.detection_number,
                "x": r.x,
                "y": r.y,
                "width": r.width,
                "height": r.height,
                "confidence": r.confidence,
            }
            for r in rows
        ],
        "count": len(rows),
    }
