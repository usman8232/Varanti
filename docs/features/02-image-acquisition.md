# Feature: Image acquisition and preprocessing

**SRS:** §3.2 FR-IMG-01..04  
**Priority:** P1  
**Status:** Backend stores uploaded bytes; capture/compression is Flutter

## Intent

Capture or import a receipt and an optional serial-label photo, then upload compressed images for OCR and archival.

## Requirements

| ID | Owner |
| --- | --- |
| FR-IMG-01 Camera viewfinder + receipt frame | Flutter |
| FR-IMG-02 Gallery import JPEG/PNG/HEIC/PDF | Flutter (PDF first page rasterized on device before upload) |
| FR-IMG-03 Secondary serial/warranty photo | Flutter + backend optional file field |
| FR-IMG-04 Edge detect, perspective, JPEG compress | Flutter. Working default: quality 65, max edge 1600px |

## Backend (this increment)

- Accept `receipt` (required) and `serial` (optional) as multipart files on OCR scan.
- Store under `{user_id}/receipts/{uuid}` and `{user_id}/serials/{uuid}` in private buckets.
- Allowed upload types: `image/jpeg`, `image/png`, `image/heic`, `image/heif`, `image/webp`. PDF upload to API is deferred until Flutter rasterizes.

## Acceptance

- Images are not world-readable; only the owning user can fetch them.
- Deleting a warranty also deletes its storage objects (see feature 07).
