# HLS Streaming Migration Guide

## Overview

The Hydroponic Monitor app has migrated from MJPEG (Motion JPEG) streaming to H.264 HLS (HTTP Live Streaming) for video playback. This provides better performance, wider compatibility, and a more modern streaming experience.

## What Changed

### Video Streaming Protocol
- **Before**: MJPEG (Motion JPEG) with custom multipart parsers
- **After**: H.264 HLS using Flutter's native `video_player` package

### Configuration
- **Environment Variable**: `MJPEG_URL` → `HLS_URL`
- **URL Format**: 
  - Old: `http://raspberrypi:8000/stream.mjpg`
  - New: `http://raspberrypi:8000/stream.m3u8`
- **Settings UI**: "MJPEG Stream URL" → "HLS Stream URL"

### Code Changes
- **Removed**: Custom MJPEG parsers (`mjpeg_stream_controller_*.dart`)
- **Removed**: MJPEG-specific tests and utilities
- **Added**: Unified `hls_stream_controller.dart` using `video_player`
- **Updated**: `VideoState` model (removed FPS/latency tracking, added buffering state)

## Benefits of HLS

1. **Native Platform Support**: Uses platform-optimized video decoders on all devices
2. **Better Performance**: Hardware-accelerated H.264 decoding
3. **Lower CPU Usage**: More efficient than software MJPEG parsing
4. **Better Battery Life**: Hardware decoding uses less power
5. **Adaptive Streaming**: HLS supports adaptive bitrate (future capability)
6. **Industry Standard**: Widely supported and well-maintained

## Server Setup

To serve HLS streams from your Raspberry Pi camera:

### Option 1: Using FFmpeg
```bash
# Install FFmpeg
sudo apt-get install ffmpeg

# Stream from camera to HLS (serves on port 8000 by default)
ffmpeg -f v4l2 -i /dev/video0 \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -f hls -hls_time 1 -hls_list_size 3 \
  -hls_flags delete_segments \
  /var/www/html/stream.m3u8
```

### Option 2: Using nginx-rtmp
```bash
# Install nginx with RTMP module
sudo apt-get install libnginx-mod-rtmp

# Configure nginx for HLS
# Add to /etc/nginx/nginx.conf:
rtmp {
    server {
        listen 1935;
        application live {
            live on;
            hls on;
            hls_path /var/www/html/hls;
            hls_fragment 1s;
        }
    }
}

# Stream camera to RTMP
ffmpeg -f v4l2 -i /dev/video0 \
  -c:v libx264 -preset ultrafast \
  -f flv rtmp://localhost/live/stream
```

### Option 3: Using RPi Camera Module
```bash
# Install picamera2
pip3 install picamera2

# Python script to generate HLS
# See: https://picamera.readthedocs.io/en/latest/recipes1.html#capturing-to-a-network-stream
```

## Configuration Updates

### Update .env file
```bash
# Old
MJPEG_URL=http://raspberrypi:8000/stream.mjpg

# New
HLS_URL=http://raspberrypi:8000/stream.m3u8
```

### Update Settings in App
1. Open the app
2. Navigate to Settings page
3. Update "HLS Stream URL" field with your new HLS endpoint
4. Save settings

## Troubleshooting

### Stream not playing
- **Check URL**: Ensure the URL ends with `.m3u8` (HLS manifest file)
- **Check CORS**: For web deployment, ensure your server allows CORS requests
- **Check Format**: Verify the stream is actually H.264 HLS, not MJPEG
- **Check Network**: Ensure the device can reach the streaming server

### Buffering issues
- **Reduce segment duration**: Use shorter HLS segments (1-2 seconds)
- **Check bandwidth**: Ensure sufficient network bandwidth
- **Optimize encoding**: Use appropriate H.264 preset (ultrafast for real-time)

### High latency
- **Use low-latency preset**: Set FFmpeg to `-preset ultrafast -tune zerolatency`
- **Reduce segment size**: Smaller HLS segments = lower latency
- **Check network**: Network delays add to stream latency

## Migration Checklist

- [ ] Update server to generate HLS streams instead of MJPEG
- [ ] Update `.env` file with `HLS_URL`
- [ ] Test stream in app on all target platforms (web, Android, iOS)
- [ ] Update any documentation referencing MJPEG
- [ ] Update deployment scripts if they reference MJPEG URLs

## Rollback (If Needed)

If you need to temporarily revert to MJPEG:

1. Check out the previous commit before HLS migration
2. Rebuild and redeploy the app
3. Keep your MJPEG server running

Note: Future app versions will not support MJPEG.

## Support

For issues with HLS streaming:
- Check the app logs for video player errors
- Verify your HLS stream works in a browser (VLC, mpv, or browser)
- Ensure your server is configured correctly for HLS delivery

## References

- [HLS Specification](https://developer.apple.com/streaming/)
- [FFmpeg HLS Guide](https://ffmpeg.org/ffmpeg-formats.html#hls-2)
- [Flutter video_player Package](https://pub.dev/packages/video_player)
