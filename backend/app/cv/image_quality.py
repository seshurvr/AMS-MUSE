"""Basic image-quality analysis for uploaded classroom photos."""
import cv2


def analyze(image_path: str) -> dict:
    """Return width/height/brightness/blur metrics plus human-readable warnings."""
    img = cv2.imread(image_path)
    if img is None:
        # Unreadable/corrupt input: report zeros with a warning, no exception.
        return {
            "width": 0,
            "height": 0,
            "brightness": 0.0,
            "blur_score": 0.0,
            "warnings": [f"Could not read image: {image_path}"],
        }

    height, width = img.shape[:2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    brightness = float(gray.mean())  # 0..255
    blur_score = float(cv2.Laplacian(gray, cv2.CV_64F).var())

    warnings: list[str] = []
    if brightness < 60:
        warnings.append(
            "Image is too dark (brightness %.0f). Consider better lighting." % brightness
        )
    elif brightness > 200:
        warnings.append(
            "Image looks overexposed (brightness %.0f). Avoid direct glare."
            % brightness
        )
    if blur_score < 100:
        warnings.append(
            "Image appears blurry (sharpness %.0f). Hold the camera steady."
            % blur_score
        )
    if width < 640:
        warnings.append(
            "Image resolution is low (%dpx wide). Person detection works best "
            "at 640px or wider." % width
        )

    return {
        "width": width,
        "height": height,
        "brightness": round(brightness, 1),
        "blur_score": round(blur_score, 1),
        "warnings": warnings,
    }
