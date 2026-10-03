#!/usr/bin/env python3
import os

os.chdir(r'C:\Users\ramic\StudioProjects\testf')

with open('lib/providers/deezer_provider.dart', 'r') as f:
    lines = f.readlines()

# Find the duplicate "state = state.copyWith(" line (should be after line 164)
dup_line_idx = None
for i in range(155, 178):
    stripped = lines[i].strip()
    if stripped == 'state = state.copyWith(' and i > 155:
        dup_line_idx = i
        break

print(f"Duplicate line at index {dup_line_idx}: {lines[dup_line_idx].rstrip()}")

if dup_line_idx is not None:
    # Remove the duplicate line
    lines.pop(dup_line_idx)
    
    # Now find the mood lines (moodTracks:, moodAlbums:, moodArtists:, moodPlaylists:)
    # These should be after artistsYouMightLike and before the closing );
    
    # Find artistsYouMightLike line
    artist_line_idx = None
    for i in range(len(lines)):
        if 'artistsYouMightLike:' in lines[i]:
            artist_line_idx = i
            break
    
    print(f"artistsYouMightLike at index {artist_line_idx}: {lines[artist_line_idx].rstrip()}")
    
    # Find the closing ');'
    close_idx = None
    for i in range(len(lines)):
        if lines[i].strip() == ');':
            close_idx = i
            break
    
    print(f"Closing ); at index {close_idx}: {lines[close_idx].rstrip()}")
    
    # Find mood lines - they should have moodTracks:, moodAlbums:, etc.
    mood_keywords = ['moodTracks:', 'moodAlbums:', 'moodArtists:', 'moodPlaylists:']
    mood_lines = []
    for i in range(artist_line_idx + 1, min(artist_line_idx + 30, len(lines))):
        for kw in mood_keywords:
            if kw in lines[i]:
                mood_lines.append(i)
                break
    
    print(f"Mood lines to move: {mood_lines}")
    print(f"Mood line contents:")
    for idx in mood_lines:
        if idx < len(lines):
            print(f"  Line {idx+1}: {lines[idx].rstrip()}")
    
    # Remove the mood lines from their current position
    for idx in sorted(mood_lines, reverse=True):
        if idx < len(lines):
            lines.pop(idx)
    
    # Insert mood lines after artistsYouMightLike line
    insert_idx = artist_line_idx + 1
    # We need to insert in reverse order so they maintain order
    # moodPlaylists, moodArtists, moodAlbums, moodTracks (reverse order)
    # But let's just insert them in the right order
    
    # Actually, let's just find where ); is and insert before it
    # First, let's re-find the closing );
    close_idx2 = None
    for i in range(len(lines)):
        if lines[i].strip() == ');':
            close_idx2 = i
            break
    
    print(f"Re-found ); at index {close_idx2}")
    
    # Insert mood lines before the closing );
    # The mood lines need to be inserted in correct order
    # moodTracks, moodAlbums, moodArtists, moodPlaylists
    
    # Let's get the mood line contents again (they were removed)
    # We need to reconstruct them
    
    # Actually, simpler approach: let's just rewrite the entire _loadInitialFeed method section
    # by finding the start and end markers
    
    # Let's just find the range from state.copyWith( to );
    start_idx = None
    end_idx = None
    for i in range(len(lines)):
        if 'state = state.copyWith(isLoading: true, error: null);' in lines[i] or (
            'state = state.copyWith(isLoading: true, error: null);' in ''.join(lines[:i+1])
        ):
            # Find the opening (
            pass
    
    # Better approach: let's just rebuild the _loadInitialFeed method properly
    # by identifying the try block and replacing the whole section
    
print("\n--- Simpler approach: rewrite the _loadInitialFeed method ---")

# Find the _loadInitialFeed method start (after _loadMoodContent call)
# and the catch block end
method_start = None
method_end = None

for i, line in enumerate(lines):
    if '_loadInitialFeed() async {' in line:
        method_start = i
    if method_start is not None and i > method_start and '}' in line and lines[i-1].strip() == '}':
        # Check if this is the end of _loadInitialFeed
        # Look for the pattern: catch (e) {
        method_end = i
        # But we need to find the actual closing
        # Let's just look for the pattern differently

print(f"Method start: {method_start}")
print(f"Lines total: {len(lines)}")

# Let me take a completely different approach - just rewrite the critical section
# by reading the file, identifying the broken part, and replacing it

# The broken section is from line 156 (state.copyWith) to line 178 ());
# We need to remove the duplicate state.copyWith on what was line 165
# and ensure the mood variables are proper params

# Let me just do a text replacement of the entire section

# Read the whole file as string
with open('lib/providers/deezer_provider.dart', 'r') as f:
    content = f.read()

# The current broken section looks like:
# "      state = state.copyWith(\n        isLoading: false,\n        ...\n      state = state.copyWith(\n      isLoading: false,\n      ...\n      );\n"
# We need to change it to:
# "      state = state.copyWith(\n        isLoading: false,\n        ...\n      moodTracks: ...,\n      moodAlbums: ...,\n      moodArtists: ...,\n      moodPlaylists: ...,\n      );\n"

# Let's find and replace the specific broken pattern
# Pattern: from "state = state.copyWith(isLoading: false," after the first set 
# through to ");\n" at the end, with the duplicate in between

# Find the first "state = state.copyWith(isLoading: false," after line 156
import re

# Split into lines for easier manipulation
lines = content.split('\n')

# Find line numbers (1-indexed for debugging)
print("\n--- Analyzing lines around the issue ---")
for i in range(150, 180):
    if i < len(lines):
        print(f"Line {i+1}: {lines[i][:100]}")

# Now let's do the replacement
# We need to:
# 1. Remove the duplicate "      state = state.copyWith(" line
# 2. Move the mood variables to be params of the first copyWith
# 3. Ensure proper closing );

print("\n--- Performing fix ---")

# Remove the duplicate line (it should be around line 165, 0-indexed 164)
# Look for "      state = state.copyWith(" that's a duplicate (not the first one)
dup_pattern = None
for i in range(155, 178):
    if lines[i].strip() == 'state = state.copyWith(':
        if i > 155:  # This is the duplicate
            dup_pattern = i
            break

print(f"Duplicate at 0-indexed: {dup_pattern}")

if dup_pattern is not None:
    # Remove it
    lines.pop(dup_pattern)
    
    # Now find the mood lines and move them
    # Find "artistsYouMightLike:" 
    artist_idx = None
    for i in range(len(lines)):
        if lines[i].strip().startswith('artistsYouMightLike:'):
            artist_idx = i
            break
    
    print(f"artistsYouMightLike at 0-indexed: {artist_idx}")
    
    # Find mood lines after artist line
    mood_data = {}
    for kw in ['moodTracks:', 'moodAlbums:', 'moodArtists:', 'moodPlaylists:']:
        for i in range(artist_idx + 1, min(artist_idx + 20, len(lines))):
            if kw in lines[i]:
                # Extract the line content
                mood_data[kw] = lines[i].strip()
                lines.pop(i)
                break
    
    print(f"Extracted mood data: {list(mood_data.keys())}")
    print(f"Remaining lines around artist area:")
    for i in range(max(0, artist_idx-1), min(len(lines), artist_idx+5)):
        print(f"  Line {i+1}: {lines[i][:80]}")
    
    # Insert mood lines after artistsYouMightLike
    # The mood lines need: moodTracks, moodAlbums, moodArtists, moodPlaylists
    # in that order, with proper formatting
    
    # Reconstruct the mood lines in correct order
    ordered_mood_keys = ['moodTracks:', 'moodAlbums:', 'moodArtists:', 'moodPlaylists:']
    mood_lines_to_insert = []
    for kw in ordered_mood_keys:
        if kw in mood_data:
            mood_lines_to_insert.append(mood_data[kw])
    
    print(f"Mood lines to insert: {mood_lines_to_insert[:2]}...")  # preview
    
    # Insert after artistsYouMightLike line
    insert_pos = artist_idx + 1
    for ml in mood_lines_to_insert:
        lines.insert(insert_pos, ml)
        insert_pos += 1
    
    print(f"Inserted {len(mood_lines_to_insert)} mood lines")
    
    # Now find and fix the closing );
    # The ); should be at the end of the copyWith params
    for i in range(len(lines)):
        if lines[i].strip() == ');':
            # Check if this is the right one (should be after all params)
            # If there's another state.copyWith after it, we have a problem
            print(f"Found ); at 0-indexed: {i}")
            # Look ahead to see if there's another state.copyWith
            if i + 1 < len(lines) and 'state = state.copyWith' in lines[i+1]:
                print("WARNING: There's another copyWith after this );")
            else:
                print("This is the correct ); position")
            break

# Write the fixed file
with open('lib/providers/deezer_provider.dart', 'w') as f:
    f.write('\n'.join(lines))

print("\nFile written successfully")