# Phase 7: Admin Product Management

## Overview
Implement admin functionality to add, edit, delete, and manage products.

## Steps

### Step 7.1: Create Products API Routes - GET & POST
- [x] **Use exact template** from `.cursor/rules/api-routes.mdc` and `P00-dev-guide.md` API Route Template
- [x] Create `src/app/api/products/route.js`
- [x] Implement GET handler: `export async function GET(request)` following template
- [x] Use Prisma client from `src/lib/prisma.js` (singleton pattern, import as `@/lib/prisma`)
- [x] Implement pagination using Prisma `take` and `skip`
- [x] Use Prisma `select` to fetch only needed fields
- [x] Implement POST handler: `export async function POST(request)` following template
- [x] Add authentication check for POST (verify session)
- [x] Validate input data (sanitize user inputs per security rules)
- [x] Handle database operations with try/catch (required pattern)
- [x] Use Prisma nested creates for relations (images, tags, features, technologies)
- [x] Return `NextResponse.json()` with proper status codes (200, 201, 400, 401, 500)
- [x] Follow error handling pattern from template

### Step 7.2: Create Product API Routes - GET, PUT, DELETE
- [x] Create `src/app/api/products/[id]/route.js`
- [x] Implement GET handler: `export async function GET(request, { params })`
- [x] Fetch single product using Prisma `findUnique` with `include` for relations
- [x] Implement PUT handler: `export async function PUT(request, { params })`
- [x] Add authentication check (verify session)
- [x] Validate input data
- [x] Use Prisma nested updates for relations (images, tags, features, technologies)
- [x] Implement DELETE handler: `export async function DELETE(request, { params })`
- [x] Add authentication check
- [x] Use Prisma `delete` (cascade deletes relations automatically)
- [x] Return `NextResponse.json()` with proper status codes
- [x] Handle errors with try/catch blocks

### Step 7.3: Create Product Form Component
- [x] Create `src/components/admin/ProductForm.js` as Client Component (`'use client'`)
- [x] Create `StyledProductForm` with theme integration (follow styled-components rules)
- [x] Use theme variables for all styling (no hardcoded values)
- [x] Add JSDoc documentation for props
- [x] Add form fields:
  - Name (required)
  - Short description (required)
  - Full description (required)
  - Category (dropdown)
  - Version
  - Release date
  - Status (dropdown: ACTIVE/ARCHIVED)
  - Download URL
- [x] Add form validation
- [x] Add error message display
- [x] Make form responsive

### Step 7.4: Create Tags Input Component
- [x] Create `src/components/admin/TagsInput.js`
- [x] Add tags input field (comma-separated or individual)
- [x] Display tags as chips/badges
- [x] Allow tag removal
- [x] Style tags input
- [x] Make component reusable

### Step 7.5: Create Features Input Component
- [x] Create `src/components/admin/FeaturesInput.js`
- [x] Add features input (one per line or comma-separated)
- [x] Display features list
- [x] Allow feature removal
- [x] Allow reordering (optional)
- [x] Style features input

### Step 7.6: Create Technologies Input Component
- [x] Create `src/components/admin/TechnologiesInput.js`
- [x] Add technologies input (one per line or comma-separated)
- [x] Display technologies list
- [x] Allow technology removal
- [x] Style technologies input

### Step 7.7: Create Image Upload Component
- [x] Create `src/components/admin/ImageUpload.js`
- [x] Add file input for images
- [x] Add image preview
- [x] Add multiple image support
- [x] Add image removal
- [x] Add image reordering
- [x] Validate file types and sizes
- [x] Style image upload component

### Step 7.8: Create Image Upload API Route
- [x] Create `src/app/api/upload/image/route.js`
- [x] Handle file upload using FormData
- [x] Validate file type (images only)
- [x] Validate file size
- [x] Generate unique filename
- [x] Save file to `public/uploads/products/`
- [x] Return file URL
- [x] Add authentication check

### Step 7.9: Create File Upload API Route
- [x] Create `src/app/api/upload/file/route.js`
- [x] Handle file upload for downloadable files
- [x] Validate file type
- [x] Validate file size
- [x] Generate unique filename
- [x] Save file to `public/downloads/`
- [x] Return file path
- [x] Add authentication check

### Step 7.10: Create Add Product Page
- [x] Create `src/app/admin/products/new/page.js` as Client Component
- [x] Add authentication check
- [x] Use ProductForm component
- [x] Handle form submission
- [x] Upload images and files
- [x] Create product with all relations
- [x] Show success message
- [x] Redirect to products list

### Step 7.11: Create Edit Product Page
- [x] Create `src/app/admin/products/[id]/page.js` as Client Component
- [x] Add authentication check
- [x] Fetch product data by ID
- [x] Pre-populate ProductForm with existing data
- [x] Handle form submission (update)
- [x] Handle image updates
- [x] Handle file updates
- [x] Show success message
- [x] Redirect to products list

### Step 7.12: Create Products List Page (Admin)
- [x] Create `src/app/admin/products/page.js` as Server Component
- [x] Add authentication check
- [x] Fetch all products from database
- [x] Display products in table or list
- [x] Add edit button for each product
- [x] Add delete button for each product
- [x] Add "Add New Product" button
- [x] Style admin products list

### Step 7.13: Create Product List Component (Admin)
- [x] Create `src/components/admin/ProductList.js`
- [x] Create styled table/list component
- [x] Display product information
- [x] Add action buttons (edit, delete)
- [x] Add status indicator
- [x] Make component responsive

### Step 7.14: Implement Delete Product Functionality
- [x] Add delete handler in ProductList component
- [x] Create confirmation modal
- [x] Call DELETE API route
- [x] Handle soft delete (archive) option
- [x] Refresh products list after deletion
- [x] Show success message

### Step 7.15: Implement Bulk Delete (Optional)
- [ ] Add checkbox selection to ProductList
- [ ] Add "Select All" functionality
- [ ] Add bulk delete button
- [ ] Create bulk delete API route
- [ ] Handle multiple deletions
- [ ] Show confirmation dialog

## Completion Criteria
- ✅ Products API routes working (GET, POST, PUT, DELETE)
- ✅ Add product page functional
- ✅ Edit product page functional
- ✅ Products list page displays all products
- ✅ Delete product working with confirmation
- ✅ Image upload working
- ✅ File upload working
- ✅ All form validations working
- ✅ All operations require authentication

