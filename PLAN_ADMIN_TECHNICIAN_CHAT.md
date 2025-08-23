# Admin-Technician Discussion Implementation Plan

## Current State Analysis
- Technician dashboard has chat functionality with operators
- Admin dashboard has chat functionality with technicians
- Technician dashboard is missing admin chat functionality
- Firebase service has all necessary methods for private chats
- Private chat model supports admin-technician conversations

## Required Updates

### 1. Add Admin Chat Tab to Technician Dashboard
- [ ] Add new tab for "Admin Discussions" in maintenance dashboard
- [ ] Fetch and display list of admins from Firestore
- [ ] Show unread message counts for admin chats
- [ ] Implement chat initiation with admins

### 2. Enhance Firebase Service
- [ ] Add method to fetch all admins (already exists: getAllAdmins())
- [ ] Ensure getUserPrivateChats() works for admin-technician chats
- [ ] Verify findExistingPrivateChat() handles admin IDs correctly

### 3. UI/UX Improvements
- [ ] Add admin list with chat buttons
- [ ] Show unread message badges
- [ ] Maintain consistent design with operator chat interface

## Implementation Steps

### Step 1: Update Maintenance Dashboard
- Add new tab for "Admin Discussions"
- Create method to fetch and display admins
- Implement chat initiation with admins similar to operator chat

### Step 2: Verify Firebase Methods
- Confirm getAllAdmins() returns proper admin data
- Ensure createPrivateChat() works with admin UIDs
- Test findExistingPrivateChat() with admin-technician pairs

### Step 3: Add Admin Chat Methods
- Create method to start chat with admin
- Handle admin user data structure (adminwewire collection)
- Ensure proper role handling in chat creation

## Files to Modify
1. `lib/screens/dashboard/maintenance_dashboard.dart` - Add admin chat tab and functionality
2. `lib/services/firebase_service.dart` - Verify admin data fetching methods

## Technical Details

### Admin Data Structure
Admins are stored in 'adminwewire' collection with UID as document ID
- Fields: name, email, createdAt, etc.

### Chat Creation
- Admin ID: Firebase Auth UID (from adminwewire collection)
- Technician ID: matricule (from technicians collection)
- Roles: 'admin' and 'maintenance_service'

### Expected Flow
1. Technician sees list of admins in new tab
2. Technician clicks chat button with admin
3. System checks for existing chat or creates new one
4. Technician navigates to chat screen with admin

## Testing Requirements
- Verify admin list displays correctly
- Test chat creation with admins
- Confirm unread message counts work
- Test real-time chat functionality

## Timeline
1. Phase 1: Add admin tab and list (1 hour)
2. Phase 2: Implement chat functionality (1 hour)
3. Phase 3: Testing and refinement (1 hour)

## Expected Outcome
- Technicians can view all admins in their dashboard
- Technicians can initiate chats with any admin
- Chat functionality works identically to operator chats
- Unread message counts are displayed
- All admin-technician communications are properly tracked
