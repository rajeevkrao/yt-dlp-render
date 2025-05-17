import os
from config.redis import redis_client
from yt_dlp import YoutubeDL

def downloadVideo(input: str):
	cookies = redis_client.get("yt-dlp:cookies")

	# throw an error if cookies is None
	if cookies is None:
			raise ValueError("No cookies found in Redis")

	# save cookies to a file
	with open("cookies.txt", "w") as f:
			f.write(cookies.decode())

	# Use yt-dlp to download a video
	ydl_opts = {"cookiefile": "cookies.txt"}  # Netscape formatted cookies file

	# URLS = ["https://www.youtube.com/watch?v=AxIyntrdHeg"]
	# URL = "https://www.youtube.com/watch?v=AxIyntrdHeg"
	with YoutubeDL(ydl_opts) as ydl:
			ydl.download(input)

	with open("cookies.txt", "r") as f:
			cookies = f.read()

	redis_client.set("yt-dlp:cookies", cookies)

	# delete the cookies file
	os.remove("cookies.txt")
