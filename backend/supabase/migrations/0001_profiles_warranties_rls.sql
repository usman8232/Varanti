-- GATE-3: profiles, warranties, RLS (SRS §6 plus storage path columns for purge)

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.warranties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    merchant_name TEXT,
    category TEXT DEFAULT 'Consumer Tech'
        CHECK (category IN (
            'Consumer Tech',
            'Home Appliances',
            'Computing',
            'Audio',
            'Power Tools',
            'Other'
        )),
    purchase_date DATE NOT NULL,
    warranty_duration_months INTEGER NOT NULL DEFAULT 12,
    warranty_expiration_date DATE NOT NULL,
    serial_number TEXT,
    price_paid NUMERIC(10, 2),
    currency VARCHAR(3) DEFAULT 'USD',
    receipt_image_url TEXT NOT NULL,
    receipt_image_path TEXT,
    serial_image_url TEXT,
    serial_image_path TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS warranties_user_id_idx ON public.warranties (user_id);
CREATE INDEX IF NOT EXISTS warranties_item_name_idx ON public.warranties (user_id, item_name);
CREATE INDEX IF NOT EXISTS warranties_merchant_idx ON public.warranties (user_id, merchant_name);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warranties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own profile" ON public.profiles;
CREATE POLICY "Users can only access their own profile"
    ON public.profiles
    FOR ALL
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can only access their own warranties" ON public.warranties;
CREATE POLICY "Users can only access their own warranties"
    ON public.warranties
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
