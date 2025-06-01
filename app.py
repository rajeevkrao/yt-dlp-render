from services.ytdlp import downloadVideo, downloadMusic
from flask import Flask, request

app = Flask(__name__)

@app.route("/video")
def video():
    resource = request.args.get("res")
    if not resource:
        return "Please provide a video URL", 400
    try:
        downloadVideo(resource)
        return "Video downloaded successfully", 200
    except Exception as e:
        return f"Error downloading video: {str(e)}", 500
  
@app.route("/music")
def music():
    resource = request.args.get("res")
    if not resource:
        return "Please provide a video URL", 400
    try:
        downloadMusic(resource)
        return "Music downloaded successfully", 200
    except Exception as e:
        return f"Error downloading video: {str(e)}", 500
   

@app.route("/")
def home():
    video = request.args.get("video")
    if not video:
        return "Please provide a video URL", 400
    try:
        downloadVideo(video)
        return "Video downloaded successfully", 200
    except Exception as e:
        return f"Error downloading video: {str(e)}", 500

if __name__ == "__main__":
    app.run(debug=True)