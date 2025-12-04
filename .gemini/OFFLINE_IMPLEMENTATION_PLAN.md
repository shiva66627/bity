# Offline Implementation Plan for MBBS Freaks App

## Overview
Make the app fully functional offline so users can access all features even without internet connectivity.

## Current Status
✅ Hive initialized for local storage
✅ connectivity_plus package available
✅ Some cache usage in splash_screen.dart
❌ Firestore persistence NOT enabled
❌ No offline-first data fetching strategy
❌ No offline state management

## Implementation Steps

### 1. Enable Firestore Offline Persistence
**File**: `lib/main.dart`
- Enable Firestore persistence with unlimited cache size
- This allows Firestore to cache all data locally
- Users can read cached data when offline

### 2. Create Offline Service
**File**: `lib/services/offline_service.dart` (NEW)
- Monitor network connectivity status
- Provide global offline state
- Handle sync when connection is restored
- Queue write operations for when online

### 3. Update Data Fetching Strategy
**Files**: All screens that fetch Firestore data
- Try cache first, then server
- Gracefully handle offline errors
- Show cached data when available
- Display offline indicator in UI

### 4. Local Data Caching
**Use Hive for**:
- User profile data
- Daily questions
- Recent activity
- Reviews
- Notes metadata
- Quiz data

### 5. Handle Authentication Offline
**File**: `lib/screens/splash_screen.dart`
- Keep user authenticated offline (Firebase Auth does this by default)
- Use cached user role
- Skip server role check when offline

### 6. Update UI Components
**Add**:
- Offline indicator banner
- Sync status indicator
- Cached data badges
- Refresh button for manual sync

### 7. Handle Write Operations
- Queue writes when offline
- Save to local Hive first
- Sync to Firestore when online
- Show pending sync indicator

## Benefits
✅ App opens instantly even without internet
✅ Users can view all previously loaded content
✅ Better user experience
✅ Reduced data usage
✅ Works in areas with poor connectivity

## Files to Modify
1. `lib/main.dart` - Enable Firestore persistence
2. `lib/services/offline_service.dart` - NEW: Offline management
3. `lib/screens/splash_screen.dart` - Better offline handling
4. `lib/screens/home_page.dart` - Offline UI + data caching
5. `lib/screens/admin_dashboard.dart` - Queue admin actions
6. All other screens - Cache-first data fetching

## Testing Plan
1. Test app launch without internet
2. Test data viewing offline
3. Test write operations offline
4. Test sync when connection restored
5. Test rapid online/offline switching
