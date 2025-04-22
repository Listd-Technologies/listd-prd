# Product Requirements Document (PRD)

## Project: Real Estate Application (Web & Mobile)

### Overview

This project aims to build a modern real estate platform accessible via web and native mobile apps. The platform will allow users to search, list, value, and communicate about properties in a user-friendly and secure environment.

---

## Features

### 1. User Registration & Profile Management

**Goal:**  
Allow users to easily register and manage their profiles on both web and mobile platforms.

**Requirements:**
- Users can register using:
  - Gmail (Google sign-in)
  - Email and password
- Registration and authentication are handled securely using ClerkJS.
- Users can update their profile information (name, contact details, profile picture, etc.) at any time.
- Profile management is consistent and accessible on both web and mobile versions.

---

### 2. Property Search & Filtering

**Goal:**  
Enable users to find properties efficiently using targeted and advanced search options.

**Requirements:**
- **Search Modes:**
  - Users must choose between searching for properties to **Rent** or **Buy**.
  - Users must select a property type:
    - Condominium
    - House and Lot
    - Warehouse
    - Vacant Lot
- **Location Search:**
  - Users can type a specific area (e.g., "Ayala Alabang") in a search box.
  - The system returns the number of available properties in that area.
- **Advanced Map Search:**
  - Users can navigate a map and draw a shape (e.g., a circle) to define a custom search area.
  - The app displays property pins within the drawn area (using geo-location search).
- **Filters:**
  - All property types: Filter by size (area) and price.
  - Condominium & House and Lot: Additional filters for number of bedrooms and bathrooms.

---

### 3. User Listings & Monetization

**Goal:**  
Allow users to post their own property listings, with a limit to encourage paid upgrades.

**Requirements:**
- Each user can post up to **two free listings**.
- Posting more than two listings requires a paid upgrade (in-app purchase or subscription).
- Listing management (add, edit, delete) is available on both web and mobile.

---

### 4. Property Valuation Tool

**Goal:**  
Provide users with an easy way to estimate the value of their property.

**Requirements:**
- Users can request a valuation for:
  - Condominium
  - House and Lot
  - Warehouse
  - Vacant Lot
- **Required Information for Valuation:**
  - **Condominium:** Floor area, bedrooms, bathrooms, parking, complete address (with Google address search for coordinates and building name)
  - **House and Lot:** Lot size, floor area, bedrooms, bathrooms, parking, complete address (with Google address search)
  - **Warehouse:** Lot size, floor area, building size, ceiling height, complete address (with Google address search)
  - **Vacant Lot:** Lot size, complete address (with Google address search)
- If the user is **not logged in**, they must provide:
  - First name
  - Last name
  - Email
  - Phone number (with WhatsApp availability checkbox)
- After submitting, the system:
  - Shows the valuation result to the user.
  - Stores all input details for future use (e.g., if the user wants to list the property later).

---

### 5. In-App Messaging & Communication

**Goal:**  
Facilitate communication between users and property owners, both within and outside the app.

**Requirements:**
- Users can send messages to property owners directly within the app.
- Each property listing and property owner profile includes a **WhatsApp button** for external communication.
- Messaging is available on both web and mobile platforms.

---

### 6. Favorites (Minor Feature)

**Goal:**  
Allow users to save and manage a collection of their favorite properties for easy access later.

**Requirements:**
- Users can add any property listing to their favorites collection.
- Users can view, organize, and remove properties from their favorites.
- Favorites are accessible and synced across both web and mobile platforms.

---

## Non-Functional Requirements

- **Security:** All user data and communications must be securely handled and stored.
- **Performance:** The app should be responsive and fast on both web and mobile.
- **Usability:** The interface must be intuitive and accessible to users of all backgrounds.
- **Scalability:** The system should be able to handle growth in users and listings.

---

## Success Metrics

- User registration and retention rates
- Number of property searches and listings
- Engagement with the valuation tool
- Volume of in-app and WhatsApp communications
- Conversion rate for paid listings

---

## Appendix

- **Backend:**
  - PostgreSQL for database
  - Encore.ts for REST API
  - Minio for static assets storage
  - Socket.io for real-time in-app messaging
- **Frontend:**
  - React Native (using Expo) for mobile
  - Next.js with shadcn for web
- **Third-Party Services:**
  - ClerkJS for authentication
  - Railway for hosting
  - Google Maps API for address and map features

---

**End of Document** 