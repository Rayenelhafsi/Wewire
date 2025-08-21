# Login Screen Authentication Enhancement

## Task: Modify login screen to fetch data from adminwewire, operators, and technicians collections without showing the list

### Steps to Complete:

1. [x] Update FirebaseService to add admin authentication methods
   - Add methods to fetch admin users from "adminwewire" collection
   - Add authentication methods for all user types

2. [x] Modify LoginScreen authentication logic
   - Update _handleLogin() to authenticate against Firestore collections
   - Add proper error handling and loading states
   - Remove any list display functionality

3. [x] Update User model if needed for proper data mapping
   - User model is already compatible with all user roles

### Progress:
- [x] Step 1: FirebaseService updates
- [x] Step 2: LoginScreen updates
- [x] Step 3: Testing and verification

### Notes:
- Adminwewire collection structure will be assumed to have similar fields to other user collections
- Authentication will be based on email/password matching across collections
- No user lists should be displayed during login process
