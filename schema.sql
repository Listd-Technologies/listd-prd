-- PostgreSQL schema for Real Estate Application
-- Supports ClerkJS integration, listings, images, favorites, messaging, property valuations, and payments

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Using VARCHAR with CHECK constraints instead of PostgreSQL ENUM types

-- Reference (lookup) tables instead of hard‑coded CHECK constraints

-- Lookup: listing types
CREATE TABLE listing_types (
    code VARCHAR(10) PRIMARY KEY
);

-- Pre‑populate
INSERT INTO listing_types(code) VALUES ('Rent'), ('Buy');

-- Lookup: property types
CREATE TABLE property_types (
    code VARCHAR(20) PRIMARY KEY
);

INSERT INTO property_types(code) VALUES ('Condominium'), ('House and Lot'), ('Warehouse'), ('Vacant Lot');

-- Lookup: listing status
CREATE TABLE listing_statuses (
    code VARCHAR(10) PRIMARY KEY
);

INSERT INTO listing_statuses(code) VALUES ('Draft'), ('Active'), ('Paused'), ('Archived');

-- Lookup: Geographical hierarchy
CREATE TABLE cities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE barangays (
    id SERIAL PRIMARY KEY,
    city_id INT REFERENCES cities(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    UNIQUE(city_id, name)
);

-- 1. Users (ClerkJS integration)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    clerk_id VARCHAR(255) UNIQUE NOT NULL, -- ClerkJS user id
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(30),
    whatsapp_available BOOLEAN DEFAULT FALSE,
    profile_picture_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. Listings
CREATE TABLE listings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(10) REFERENCES listing_types(code) NOT NULL,
    property_type VARCHAR(20) REFERENCES property_types(code) NOT NULL,
    status VARCHAR(10) REFERENCES listing_statuses(code) DEFAULT 'ACTIVE',
    payment_id UUID, -- FK added after user_payments is defined
    title VARCHAR(255),
    description TEXT,
    price NUMERIC(15,2),
    -- property-specific details are now in separate tables
    address TEXT,
    city_id INT REFERENCES cities(id),
    barangay_id INT REFERENCES barangays(id),
    region VARCHAR(100),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geom geography(Point,4326),
    tsv tsvector GENERATED ALWAYS AS (
        to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(description,''))
    ) STORED,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for spatial, text, and filter search
CREATE INDEX listings_geom_gix   ON listings USING GIST (geom);
CREATE INDEX listings_search_idx ON listings(property_type, type, price);
CREATE INDEX listings_tsv_gin    ON listings USING GIN (tsv);

-- 3. Listing Images (Minio storage)
CREATE TABLE listing_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    position INT NOT NULL DEFAULT 0, -- for image ordering
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(listing_id, position)
);

-- Index to quickly fetch images in order
CREATE INDEX listing_images_list_pos_idx ON listing_images(listing_id, position);

-- 4. Favorites
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, listing_id)
);

-- Index for quick favorites retrieval
CREATE INDEX favorites_user_created_idx ON favorites(user_id, created_at DESC);

-- 5. Messaging (Socket.io)
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    user1_id UUID REFERENCES users(id) ON DELETE CASCADE,
    user2_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    sent_at TIMESTAMP DEFAULT NOW(),
    is_read BOOLEAN DEFAULT FALSE
);

-- Soft delete capability and message retrieval index
ALTER TABLE messages ADD COLUMN deleted_at TIMESTAMPTZ;
CREATE INDEX messages_conv_sent_idx
  ON messages(conversation_id, sent_at DESC)
  WHERE deleted_at IS NULL;

-- 6. Property Valuations
CREATE TABLE property_valuations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id), -- nullable for guest
    property_type VARCHAR(20) REFERENCES property_types(code) NOT NULL,
    floor_area NUMERIC(10,2),
    lot_size NUMERIC(10,2),
    bedrooms INT,
    bathrooms INT,
    parking INT,
    building_size NUMERIC(10,2),
    ceiling_height NUMERIC(10,2),
    address TEXT,
    city_id INT REFERENCES cities(id),
    barangay_id INT REFERENCES barangays(id),
    region VARCHAR(100),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    guest_first_name VARCHAR(100),
    guest_last_name VARCHAR(100),
    guest_email VARCHAR(255),
    guest_phone VARCHAR(30),
    guest_whatsapp_available BOOLEAN,
    valuation_result NUMERIC(15,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 7. Payments (for paid listings/subscriptions)
CREATE TABLE user_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    payment_type VARCHAR(20), -- e.g., 'LISTING', 'SUBSCRIPTION'
    amount NUMERIC(10,2),
    payment_status VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Add FK for listings.payment_id now that user_payments exists
ALTER TABLE listings
    ADD CONSTRAINT listings_payment_fk
    FOREIGN KEY (payment_id) REFERENCES user_payments(id);

-- Trigger to enforce two free active listings per user
CREATE OR REPLACE FUNCTION check_free_listing_quota()
RETURNS trigger AS $$
BEGIN
    IF NEW.payment_id IS NULL THEN
        IF (SELECT COUNT(*) FROM listings
            WHERE user_id = NEW.user_id
              AND payment_id IS NULL
              AND status = 'ACTIVE') >= 2 THEN
            RAISE EXCEPTION 'Free listing quota exceeded – payment required for additional listings.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_free_listing_limit
BEFORE INSERT ON listings
FOR EACH ROW EXECUTE FUNCTION check_free_listing_quota();

-- Trigger: ensure at least 3 images before listing status can be set to Active
CREATE OR REPLACE FUNCTION check_min_images()
RETURNS trigger AS $$
BEGIN
    IF NEW.status = 'Active' THEN
        IF (SELECT COUNT(*) FROM listing_images WHERE listing_id = NEW.id) < 3 THEN
            RAISE EXCEPTION 'At least 3 images are required for an Active listing.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_min_images_active
BEFORE UPDATE ON listings
FOR EACH ROW EXECUTE FUNCTION check_min_images();

-- 8. Activity Logs (optional)
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(100),
    details JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Ensure only one conversation per listing between the same two users
CREATE UNIQUE INDEX conversations_listing_users_uidx
  ON conversations (
      listing_id,
      LEAST(user1_id, user2_id),
      GREATEST(user1_id, user2_id)
  );

-- Property-specific detail tables

-- Condominium details
CREATE TABLE condo_details (
    listing_id UUID PRIMARY KEY REFERENCES listings(id) ON DELETE CASCADE,
    floor_area NUMERIC(10,2),
    bedrooms INT,
    bathrooms INT,
    parking INT
);

-- House and Lot details
CREATE TABLE house_details (
    listing_id UUID PRIMARY KEY REFERENCES listings(id) ON DELETE CASCADE,
    lot_size NUMERIC(10,2),
    floor_area NUMERIC(10,2),
    bedrooms INT,
    bathrooms INT,
    parking INT
);

-- Warehouse details
CREATE TABLE warehouse_details (
    listing_id UUID PRIMARY KEY REFERENCES listings(id) ON DELETE CASCADE,
    lot_size NUMERIC(10,2),
    floor_area NUMERIC(10,2),
    building_size NUMERIC(10,2),
    ceiling_height NUMERIC(10,2)
);

-- Vacant Lot details
CREATE TABLE vacantlot_details (
    listing_id UUID PRIMARY KEY REFERENCES listings(id) ON DELETE CASCADE,
    lot_size NUMERIC(10,2)
); 