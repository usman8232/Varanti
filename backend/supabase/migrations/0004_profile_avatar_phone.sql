-- Step 1 Sync Migration: phone number & profile avatar support + avatars bucket RLS

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS avatar_path TEXT;

-- Keep trigger compatible with Email, Phone OTP, Google, Facebook, and Apple Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_full_name TEXT;
    v_avatar_url TEXT;
    v_phone TEXT;
BEGIN
    v_full_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'name'
    );
    v_avatar_url := COALESCE(
        NEW.raw_user_meta_data->>'avatar_url',
        NEW.raw_user_meta_data->>'picture'
    );
    v_phone := COALESCE(
        NEW.phone,
        NEW.raw_user_meta_data->>'phone'
    );

    INSERT INTO public.profiles (id, email, full_name, phone, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        v_full_name,
        v_phone,
        v_avatar_url
    )
    ON CONFLICT (id) DO UPDATE
        SET email = COALESCE(NULLIF(EXCLUDED.email, ''), public.profiles.email),
            full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
            phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
            avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url),
            updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE PROCEDURE public.handle_new_user();

-- Private avatars bucket; object path must start with auth.uid()
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users manage own avatar objects" ON storage.objects;
CREATE POLICY "Users manage own avatar objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
