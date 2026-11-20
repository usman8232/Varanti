-- Private buckets; object path must start with auth.uid()

INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('serial-labels', 'serial-labels', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users manage own receipt objects" ON storage.objects;
CREATE POLICY "Users manage own receipt objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id = 'receipts'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'receipts'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users manage own serial objects" ON storage.objects;
CREATE POLICY "Users manage own serial objects"
    ON storage.objects
    FOR ALL
    TO authenticated
    USING (
        bucket_id = 'serial-labels'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'serial-labels'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
