import { useCallback, useRef, useState } from 'react';
import type { ReactNode } from 'react';

interface ImageViewerProps {
  src: string;
  alt: string;
  children?: ReactNode; // overlay content (e.g. DetectionOverlay), positioned over the image
  onNaturalSize?: (w: number, h: number) => void;
}

const MIN_ZOOM = 0.5;
const MAX_ZOOM = 4;

/**
 * Image viewer with zoom in / zoom out / fit / reset controls.
 * Children are rendered in an absolutely positioned layer over the image so
 * detection boxes scale together with it.
 */
export function ImageViewer({ src, alt, children, onNaturalSize }: ImageViewerProps) {
  const [zoom, setZoom] = useState(1);
  const imgRef = useRef<HTMLImageElement>(null);

  const zoomBy = useCallback((factor: number) => {
    setZoom((z) => Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, +(z * factor).toFixed(2))));
  }, []);

  const reset = useCallback(() => setZoom(1), []);

  return (
    <div className="overflow-hidden rounded-xl border border-slate-200 bg-slate-900">
      <div className="flex items-center justify-between border-b border-slate-700 px-3 py-2">
        <div className="flex items-center gap-1" role="group" aria-label="Image zoom controls">
          <button
            type="button"
            onClick={() => zoomBy(1.25)}
            disabled={zoom >= MAX_ZOOM}
            aria-label="Zoom in"
            className="btn-focus rounded p-1.5 text-slate-200 hover:bg-slate-700 disabled:opacity-40"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
              <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
              <path d="M11 11l3.5 3.5M7 4.8v4.4M4.8 7h4.4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </button>
          <button
            type="button"
            onClick={() => zoomBy(0.8)}
            disabled={zoom <= MIN_ZOOM}
            aria-label="Zoom out"
            className="btn-focus rounded p-1.5 text-slate-200 hover:bg-slate-700 disabled:opacity-40"
          >
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
              <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
              <path d="M11 11l3.5 3.5M4.8 7h4.4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
            </svg>
          </button>
          <button
            type="button"
            onClick={reset}
            aria-label="Reset zoom to fit"
            className="btn-focus rounded px-2 py-1.5 text-xs font-medium text-slate-200 hover:bg-slate-700"
          >
            Fit
          </button>
        </div>
        <span className="text-xs tabular-nums text-slate-400" aria-live="polite">
          {Math.round(zoom * 100)}%
        </span>
      </div>

      <div className="max-h-[70vh] overflow-auto bg-slate-900 p-2">
        <div
          className="relative mx-auto"
          style={{ width: `${zoom * 100}%`, maxWidth: zoom <= 1 ? '100%' : undefined }}
        >
          <img
            ref={imgRef}
            src={src}
            alt={alt}
            className="block w-full select-none"
            style={{ maxWidth: zoom > 1 ? 'none' : '100%' }}
            draggable={false}
            onLoad={(e) => {
              const img = e.currentTarget;
              onNaturalSize?.(img.naturalWidth, img.naturalHeight);
            }}
          />
          {children}
        </div>
      </div>
    </div>
  );
}
