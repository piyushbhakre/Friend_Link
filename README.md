# Friend Link – Real-Time Chat Application

Friend Link is a real-time chat application built with **Flutter** and integrated with **Firebase Authentication** for number-based authentication. This app allows users to send messages in real-time after successful number verification and also includes user profile management.

## Features
- Firebase Authentication for number-based login.
- Real-time messaging functionality.
- User search and profile management.
- Ability to view and edit user details.

## Firebase Authentication
The app uses **Firebase Authentication** for OTP-based phone number verification. Below are the test numbers and OTPs to use:

### Test Numbers and OTPs:
- **+91 98765 43211** – OTP: `111111`
- **+91 1234 567 899** – OTP: `111111`
- **+91 1234 567 888** – OTP: `111111`
- **+91 1234 567 890** – OTP: `111111`

## How to Use the App

1. **OTP Authentication**:
   - Open the app, enter one of the above test numbers.
   - Enter the corresponding OTP to complete the authentication.

2. **Search for Users**:
   - After successful OTP authentication, click on the floating action button on the home screen.
   - Use the search bar to search for one of the test numbers (e.g., `+91 1234 567 888` or `+91 1234 567 890`).
   - If the number is registered, a user card will appear.

3. **Sending Messages**:
   - Once a user is found, open the chat screen and send a message.
   - The message will appear in real-time on the home screen.

4. **View and Edit User Profile**:
   - Click on the profile icon in the top-right corner of the home screen to view the current user’s profile.
   - From there, you can view or edit the user’s details.

## Test Profiles
The following numbers are pre-registered in the app for you to test:

- **+91 1234 567 888**
- **+91 1234 567 890**

You can also test new users with the other numbers.

## Known Issues
- Some UI elements may be slightly misaligned in certain positions. Apologies for any inconvenience caused.

## GitHub Repository

You can access the full source code and documentation for this project here:

[Friend Link GitHub Repository](https://github.com/piyushbhakre/Friend_Link)

## Running the Application

To run the app on your local machine, make sure you have **Flutter** installed. Then, use the following command to run the app:

```bash
flutter run
````

