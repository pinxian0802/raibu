-- Enable PostGIS extension if needed for advanced geo queries (optional, but good for maps)
-- create extension if not exists postgis;

-- 1. Points Table
create table public.points (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) not null,
  title text not null,
  description text,
  lat double precision not null,
  lng double precision not null,
  likes_count int default 0, -- Cached count
  comments_count int default 0, -- Cached count
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Images Table
create table public.images (
  id uuid default gen_random_uuid() primary key,
  point_id uuid references public.points(id) on delete cascade not null,
  uploader_id uuid references auth.users(id) not null,
  image_url text not null, -- R2 URL or path
  thumbnail_url text,      -- R2 Thumbnail URL or path
  taken_at timestamp with time zone,
  latitude double precision,
  longitude double precision,
  country text,
  administrative_area text,
  locality text,
  sub_locality text,
  thoroughfare text,
  sub_thoroughfare text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Point Likes Table
create table public.point_likes (
  id uuid default gen_random_uuid() primary key,
  point_id uuid references public.points(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(point_id, user_id)
);

-- 4. Point Comments Table
create table public.point_comments (
  id uuid default gen_random_uuid() primary key,
  point_id uuid references public.points(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  content text not null,
  likes_count int default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. Comment Likes Table
create table public.comment_likes (
  id uuid default gen_random_uuid() primary key,
  comment_id uuid references public.point_comments(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(comment_id, user_id)
);

-- Enable Row Level Security (RLS)
alter table public.points enable row level security;
alter table public.images enable row level security;
alter table public.point_likes enable row level security;
alter table public.point_comments enable row level security;
alter table public.comment_likes enable row level security;

-- Policies

-- Points
create policy "Points are viewable by everyone" on public.points for select using (true);
create policy "Users can insert their own points" on public.points for insert with check (auth.uid() = user_id);
create policy "Users can update their own points" on public.points for update using (auth.uid() = user_id);
create policy "Users can delete their own points" on public.points for delete using (auth.uid() = user_id);

-- Images
create policy "Images are viewable by everyone" on public.images for select using (true);
create policy "Users can insert images" on public.images for insert with check (auth.uid() = uploader_id);

-- Point Likes
create policy "Likes are viewable by everyone" on public.point_likes for select using (true);
create policy "Users can insert likes" on public.point_likes for insert with check (auth.uid() = user_id);
create policy "Users can delete their own likes" on public.point_likes for delete using (auth.uid() = user_id);

-- Comments
create policy "Comments are viewable by everyone" on public.point_comments for select using (true);
create policy "Users can insert comments" on public.point_comments for insert with check (auth.uid() = user_id);

-- Comment Likes
create policy "Comment Likes are viewable by everyone" on public.comment_likes for select using (true);
create policy "Users can insert comment likes" on public.comment_likes for insert with check (auth.uid() = user_id);
create policy "Users can delete their own comment likes" on public.comment_likes for delete using (auth.uid() = user_id);

-- Realtime
alter publication supabase_realtime add table public.points;
alter publication supabase_realtime add table public.images;
alter publication supabase_realtime add table public.point_likes;
alter publication supabase_realtime add table public.point_comments;
alter publication supabase_realtime add table public.comment_likes;

-- Functions & Triggers for Counts (Optional but recommended for performance)
-- You can add triggers here to update points.likes_count, points.comments_count, point_comments.likes_count
