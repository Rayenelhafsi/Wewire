# Revised Login System Implementation

## Task: 
- Admin users login with email/password from adminwewire collection
- Operators and technicians login with matricule only (no email/password)
- Fetch all user data from Firestore collections instead of hardcoded

## Steps to Complete:

1. [x] Update MatriculeLoginScreen to fetch operators/technicians from Firestore
   - Remove hardcoded lists
   - Add loading states and error handling
   - Keep matricule-only login for operators/technicians

2. [x] Update LoginScreen to be admin-only with email/password
   - Modify to only handle admin authentication
   - Remove role selection dropdown (since it's admin-only)
   - Use adminwewire collection for authentication

3. [x] Update navigation/routing to use appropriate login screens
   - Create landing screen to choose login method
   - Add routes for both admin and matricule login screens
   - Update main.dart with new routing structure

4. [x] Update FirebaseService authentication methods
   - Separate admin authentication from operator/technician authentication
   - Add methods to fetch operators/technicians by matricule

## Current Understanding:
- MatriculeLoginScreen: Used for operators/technicians with matricule-only login
- LoginScreen: Should be modified for admin-only email/password authentication
- Both should fetch data from Firestore instead of using hardcoded values
