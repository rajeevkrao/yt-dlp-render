from services.ytdlp import downloadVideo, downloadMusic
import sys

mode, resource = sys.argv[1:]

modes = {
    'video': downloadVideo,
    'music': downloadMusic,
}

print(f"Mode: {mode}, Resource: {resource}")


modes[mode](resource)