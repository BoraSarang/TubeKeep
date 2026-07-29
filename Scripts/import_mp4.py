#!/usr/bin/env python3
"""Scan /Users/lee/Documents/TubeKeep for MP4 files and import into SwiftData store."""

import os
import re
import sqlite3
import plistlib
import struct
import time
from datetime import datetime, timezone, timedelta

OUTPUT_DIR = "/Users/lee/Documents/TubeKeep"
STORE_PATH = os.path.expanduser("~/Library/Application Support/com.borasarang.tubekeep/default.store")

# Core Data reference date: Jan 1, 2001 00:00:00 UTC
REFERENCE_DATE = datetime(2001, 1, 1, tzinfo=timezone.utc)
SECONDS_BETWEEN_1970_AND_2001 = 978307200  # 2001-01-01 - 1970-01-01 in seconds

def to_coredata_date(dt):
    """Convert a datetime to Core Data timestamp (seconds since 2001-01-01)."""
    if dt is None:
        return None
    if isinstance(dt, (int, float)):
        # assume Unix timestamp
        return float(dt) - SECONDS_BETWEEN_1970_AND_2001
    return (dt - REFERENCE_DATE).total_seconds()

EMPTY_TAGS_BLOB = bytes([
    0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x30, 0x30, 0xd4, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x0a, 0x58, 0x24, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x59, 0x24, 0x61, 0x72, 0x63, 0x68,
    0x69, 0x76, 0x65, 0x72, 0x54, 0x24, 0x74, 0x6f, 0x70, 0x58, 0x24, 0x6f, 0x62, 0x6a, 0x65, 0x63,
    0x74, 0x73, 0x12, 0x00, 0x01, 0x86, 0xa0, 0x5f, 0x10, 0x0f, 0x4e, 0x53, 0x4b, 0x65, 0x79, 0x65,
    0x64, 0x41, 0x72, 0x63, 0x68, 0x69, 0x76, 0x65, 0x72, 0xd1, 0x08, 0x09, 0x54, 0x72, 0x6f, 0x6f,
    0x74, 0x80, 0x01, 0xa3, 0x0b, 0x0c, 0x11, 0x55, 0x24, 0x6e, 0x75, 0x6c, 0x6c, 0xd2, 0x0d, 0x0e,
    0x0f, 0x10, 0x5a, 0x4e, 0x53, 0x2e, 0x6f, 0x62, 0x6a, 0x65, 0x63, 0x74, 0x73, 0x56, 0x24, 0x63,
    0x6c, 0x61, 0x73, 0x73, 0xa0, 0x80, 0x02, 0xd2, 0x12, 0x13, 0x14, 0x15, 0x5a, 0x24, 0x63, 0x6c,
    0x61, 0x73, 0x73, 0x6e, 0x61, 0x6d, 0x65, 0x58, 0x24, 0x63, 0x6c, 0x61, 0x73, 0x73, 0x65, 0x73,
    0x57, 0x4e, 0x53, 0x41, 0x72, 0x72, 0x61, 0x79, 0xa2, 0x14, 0x16, 0x58, 0x4e, 0x53, 0x4f, 0x62,
    0x6a, 0x65, 0x63, 0x74, 0x08, 0x11, 0x1a, 0x24, 0x29, 0x32, 0x37, 0x49, 0x4c, 0x51, 0x53, 0x57,
    0x5d, 0x62, 0x6d, 0x74, 0x75, 0x77, 0x7c, 0x87, 0x90, 0x98, 0x9b, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x17, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xa4,
])

def encode_string_array(arr):
    """Encode [String] as NSKeyedArchiver binary plist (using pre-encoded empty array)."""
    return EMPTY_TAGS_BLOB

def parse_filename(filename):
    """Parse filename like '001 - Title.videoId.mp4' into index, title, video_id."""
    # Pattern: optional index - title.videoId.mp4
    # Examples: "001 - Title.gnNTRxxzKBM.mp4", "Title.a663vWPpMgc.mp4"
    pattern = r'(?:(\d+)\s*-\s*)?(.+?)\.([a-zA-Z0-9_-]{11})\.mp4$'
    m = re.match(pattern, filename)
    if not m:
        return None, None, None
    index_str = m.group(1)
    title = m.group(2).strip()
    video_id = m.group(3)
    index = int(index_str) if index_str else None
    return index, title, video_id

def parse_upload_date_from_file(filepath):
    """Try to get upload date from file's creation/modification time."""
    st = os.stat(filepath)
    return st.st_birthtime  # creation time (macOS)

def main():
    conn = sqlite3.connect(STORE_PATH)
    cur = conn.cursor()
    
    # Get next PK value
    cur.execute("SELECT Z_MAX FROM Z_PRIMARYKEY WHERE Z_NAME = 'LibraryItem'")
    row = cur.fetchone()
    next_pk = (row[0] if row else 0) + 1
    
    inserted = 0
    skipped = 0
    
    # Walk through all channel directories
    for channel_dir in sorted(os.listdir(OUTPUT_DIR)):
        channel_path = os.path.join(OUTPUT_DIR, channel_dir)
        if not os.path.isdir(channel_path):
            continue
        
        channel_name = channel_dir
        
        # Find all MP4 files
        mp4_files = [f for f in os.listdir(channel_path) if f.endswith('.mp4')]
        mp4_files.sort()
        
        for mp4_file in mp4_files:
            filepath = os.path.join(channel_path, mp4_file)
            
            index, title, video_id = parse_filename(mp4_file)
            if not video_id:
                print(f"  ⚠️  Could not parse video ID from: {mp4_file}")
                skipped += 1
                continue
            
            # Check if already exists
            cur.execute("SELECT Z_PK FROM ZLIBRARYITEM WHERE ZID = ?", (video_id,))
            if cur.fetchone():
                print(f"  ⏭️  Already exists: {video_id} - {title}")
                skipped += 1
                continue
            
            upload_ts = parse_upload_date_from_file(filepath)
            
            # Build thumbnail URL
            thumbnail_url = f"https://i.ytimg.com/vi/{video_id}/mqdefault.jpg"
            
            # Channel ID - we'll use a placeholder
            # Try to determine if channel_dir has embedded channel ID in format "name_id"
            channel_id = None
            # The app stores channels in SubscribedChannel table
            # We'll set channel ID from existing data or leave as placeholder
            cur.execute("SELECT ZID FROM ZSUBSCRIBEDCHANNEL WHERE ZNAME = ?", (channel_name,))
            ch_row = cur.fetchone()
            if ch_row:
                channel_id = ch_row[0]
            
            if not channel_id:
                # Generate a placeholder channel ID
                safe_name = channel_name.strip()
                channel_id = f"UC_{safe_name[:20]}"
            
            now = to_coredata_date(time.time())
            download_date = to_coredata_date(upload_ts or time.time())
            upload_date = to_coredata_date(upload_ts) if upload_ts else None
            
            # Encode tags as empty array (NSKeyedArchiver format)
            tags_blob = encode_string_array([])
            
            # Insert
            cur.execute("""
                INSERT INTO ZLIBRARYITEM (
                    Z_PK, Z_ENT, Z_OPT,
                    ZCHANNELUPLOADINDEX, ZDURATION,
                    ZDOWNLOADDATE, ZUPLOADDATE,
                    ZCHANNELID, ZCHANNELNAME, ZFILEPATH, ZID,
                    ZSUBTITLELANGUAGE, ZSUMMARY,
                    ZTHUMBNAILURL, ZTITLE, ZTRANSCRIPT,
                    ZTAGS, ZCHAPTERS
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                next_pk, 1, 1,   # Z_PK, Z_ENT, Z_OPT
                index, None,  # channelUploadIndex, duration
                download_date, upload_date,
                channel_id, channel_name, filepath, video_id,
                None, None,  # subtitleLanguage, summary
                thumbnail_url, title, None,  # transcript
                tags_blob, None  # tags, chapters
            ))
            
            print(f"  ✅ {video_id}: {title}")
            inserted += 1
            next_pk += 1
    
    # Update Z_MAX
    cur.execute("UPDATE Z_PRIMARYKEY SET Z_MAX = ? WHERE Z_NAME = 'LibraryItem'", (next_pk - 1,))
    
    conn.commit()
    conn.close()
    
    print(f"\n{'='*50}")
    print(f"Total: {inserted} inserted, {skipped} skipped")

if __name__ == "__main__":
    main()
