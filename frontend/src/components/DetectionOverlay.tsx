import type { Detection } from '../services/api';

interface DetectionOverlayProps {
  detections: Detection[];
  imageWidth: number; // natural pixel size of the image
  imageHeight: number;
  selectedId?: number | null;
  onSelect?: (detectionId: number) => void;
  mappedNames?: Map<number, string>; // detectionId -> student name (teacher-mapped)
}

const boxColors = [
  '#2563eb', '#059669', '#d97706', '#7c3aed', '#dc2626',
  '#0891b2', '#be185d', '#65a30d', '#c026d3', '#ea580c',
];

/**
 * Renders detection boxes positioned over the displayed image.
 * Boxes are defined in original-image pixel coordinates and scaled to fit.
 */
export function DetectionOverlay({
  detections,
  imageWidth,
  imageHeight,
  selectedId,
  onSelect,
  mappedNames,
}: DetectionOverlayProps) {
  if (imageWidth <= 0 || imageHeight <= 0) return null;

  return (
    <div className="pointer-events-none absolute inset-0" aria-hidden={!onSelect}>
      {detections.map((d, i) => {
        const left = (d.x / imageWidth) * 100;
        const top = (d.y / imageHeight) * 100;
        const width = (d.width / imageWidth) * 100;
        const height = (d.height / imageHeight) * 100;
        const color = boxColors[i % boxColors.length];
        const selected = selectedId === d.id;
        const mappedName = mappedNames?.get(d.id);
        return (
          <div
            key={d.id}
            className="pointer-events-auto absolute"
            style={{ left: `${left}%`, top: `${top}%`, width: `${width}%`, height: `${height}%` }}
          >
            <button
              type="button"
              onClick={() => onSelect?.(d.id)}
              aria-label={`Select Person ${d.detection_number}${mappedName ? `, mapped to ${mappedName}` : ', unmapped'}`}
              className="btn-focus block h-full w-full rounded-[2px]"
              style={{
                border: `2px solid ${color}`,
                boxShadow: selected ? `0 0 0 3px ${color}66` : undefined,
                background: selected ? `${color}22` : `${color}11`,
              }}
            />
            <span
              className="absolute -top-7 left-0 flex items-center gap-1 whitespace-nowrap rounded px-1.5 py-0.5 text-[11px] font-semibold text-white shadow"
              style={{ background: color }}
              aria-hidden="true"
            >
              Person {d.detection_number} · {Math.round(d.confidence * 100)}%
              {mappedName ? <span className="font-normal opacity-90">· {mappedName}</span> : null}
            </span>
            {mappedName && (
              <span
                className="absolute -bottom-6 left-0 flex items-center gap-1 whitespace-nowrap rounded bg-emerald-600 px-1.5 py-0.5 text-[10px] font-semibold text-white shadow"
                aria-hidden="true"
              >
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                  <path d="M2 5.4l2 2 4-4.4" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                Teacher-confirmed
              </span>
            )}
          </div>
        );
      })}
    </div>
  );
}
