---
alwaysApply: true
---
# Storage Rules

Purpose: control document and file storage behavior.

Rules:
- all file operations go through the storage abstraction
- provider selection is configuration-driven
- sensitive reports, exports, and legal evidence must support encryption and controlled download access
- file metadata belongs in the database; binary provider details stay behind the storage service
- retention and deletion workflows must preserve audit evidence
- routes and controllers must not talk directly to the filesystem or S3 client
