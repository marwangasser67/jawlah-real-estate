-- Allow admin-uploaded video files for the homepage hero cover.
-- Run this once in Supabase Dashboard → SQL Editor.
update storage.buckets
set allowed_mime_types = array['image/jpeg','image/png','image/webp','video/mp4','video/webm'],
    file_size_limit = 10485760
where id = 'site-assets';
