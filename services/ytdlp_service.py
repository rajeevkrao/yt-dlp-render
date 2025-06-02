import os
import uuid
import tempfile
from datetime import datetime, timedelta
from minio import Minio
from elasticsearch import Elasticsearch
import redis
import yt_dlp
from config.config import Config

class YTDLPService:
    def __init__(self):
        # Initialize MinIO client
        self.minio_client = Minio(
            Config.MINIO_ENDPOINT,
            access_key=Config.MINIO_ACCESS_KEY,
            secret_key=Config.MINIO_SECRET_KEY,
            secure=Config.MINIO_SECURE
        )
        
        # Initialize Elasticsearch
        self.es = Elasticsearch([Config.ELASTICSEARCH_URL])
        
        # Initialize Redis
        self.redis_client = redis.from_url(Config.REDIS_URL)
        
        # Ensure bucket exists
        self._ensure_bucket_exists()
    
    def _ensure_bucket_exists(self):
        """Ensure MinIO bucket exists"""
        try:
            if not self.minio_client.bucket_exists(Config.MINIO_BUCKET):
                self.minio_client.make_bucket(Config.MINIO_BUCKET)
        except Exception as e:
            print(f"Error creating bucket: {e}")
    
    def get_video_info(self, url):
        """Extract video information without downloading"""
        try:
            ydl_opts = {
                'quiet': True,
                'no_download': True,
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                
            return {
                'title': info.get('title', 'Unknown'),
                'duration': info.get('duration', 0),
                'uploader': info.get('uploader', 'Unknown'),
                'upload_date': info.get('upload_date', ''),
                'description': info.get('description', ''),
                'thumbnail': info.get('thumbnail', ''),
                'view_count': info.get('view_count', 0),
                'formats': [f for f in info.get('formats', []) if f.get('ext') in Config.ALLOWED_FORMATS]
            }
        except Exception as e:
            raise Exception(f"Failed to extract video info: {str(e)}")
    
    def download_video(self, url, user_id, format_id=None):
        """Download video and store in MinIO"""
        try:
            # Generate unique filename
            video_id = str(uuid.uuid4())
            temp_dir = tempfile.mkdtemp()
            
            # Get video info first
            video_info = self.get_video_info(url)
            
            # Configure yt-dlp options
            ydl_opts = {
                'outtmpl': os.path.join(temp_dir, f'{video_id}.%(ext)s'),
                'format': format_id if format_id else 'best[ext=mp4]/best',
                'writeinfojson': True,
                'writethumbnail': True,
            }
            
            # Download video
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])
            
            # Find downloaded files
            downloaded_files = os.listdir(temp_dir)
            video_file = None
            
            for file in downloaded_files:
                if any(file.endswith(f'.{ext}') for ext in Config.ALLOWED_FORMATS):
                    video_file = file
                    break
            
            if not video_file:
                raise Exception("No video file found after download")
            
            video_path = os.path.join(temp_dir, video_file)
            file_size = os.path.getsize(video_path)
            
            # Check file size limit
            if file_size > Config.MAX_VIDEO_SIZE * 1024 * 1024:
                raise Exception(f"Video size exceeds {Config.MAX_VIDEO_SIZE}MB limit")
            
            # Upload to MinIO
            object_name = f"{user_id}/{video_id}/{video_file}"
            
            self.minio_client.fput_object(
                Config.MINIO_BUCKET,
                object_name,
                video_path,
                content_type='video/mp4'
            )
            
            # Store metadata in Elasticsearch
            metadata = {
                'video_id': video_id,
                'user_id': user_id,
                'url': url,
                'title': video_info['title'],
                'duration': video_info['duration'],
                'uploader': video_info['uploader'],
                'upload_date': video_info['upload_date'],
                'description': video_info['description'],
                'thumbnail': video_info['thumbnail'],
                'view_count': video_info['view_count'],
                'file_name': video_file,
                'file_size': file_size,
                'download_date': datetime.now().isoformat(),
                'expiry_date': (datetime.now() + timedelta(days=Config.VIDEO_EXPIRY_DAYS)).isoformat(),
                'object_name': object_name,
                'status': 'completed'
            }
            
            self.es.index(
                index='video_downloads',
                id=video_id,
                body=metadata
            )
            
            # Clean up temp files
            import shutil
            shutil.rmtree(temp_dir)
            
            return {
                'video_id': video_id,
                'title': video_info['title'],
                'file_name': video_file,
                'file_size': file_size,
                'download_url': f"/download/{video_id}"
            }
            
        except Exception as e:
            # Clean up temp files on error
            try:
                import shutil
                shutil.rmtree(temp_dir)
            except:
                pass
            raise Exception(f"Download failed: {str(e)}")
    
    def get_user_videos(self, user_id, page=1, size=10):
        """Get user's downloaded videos"""
        try:
            query = {
                "query": {
                    "bool": {
                        "must": [
                            {"term": {"user_id": user_id}},
                            {"range": {"expiry_date": {"gte": datetime.now().isoformat()}}}
                        ]
                    }
                },
                "sort": [{"download_date": {"order": "desc"}}],
                "from": (page - 1) * size,
                "size": size
            }
            
            result = self.es.search(index='video_downloads', body=query)
            
            videos = []
            for hit in result['hits']['hits']:
                video = hit['_source']
                video['id'] = hit['_id']
                videos.append(video)
            
            return {
                'videos': videos,
                'total': result['hits']['total']['value'],
                'page': page,
                'pages': (result['hits']['total']['value'] + size - 1) // size
            }
            
        except Exception as e:
            raise Exception(f"Failed to retrieve videos: {str(e)}")
    
    def get_download_url(self, video_id, user_id):
        """Generate presigned URL for video download"""
        try:
            # Verify video belongs to user
            result = self.es.get(index='video_downloads', id=video_id)
            video = result['_source']
            
            if video['user_id'] != user_id:
                raise Exception("Unauthorized access")
            
            if datetime.fromisoformat(video['expiry_date']) < datetime.now():
                raise Exception("Video has expired")
            
            # Generate presigned URL (valid for 1 hour)
            url = self.minio_client.presigned_get_object(
                Config.MINIO_BUCKET,
                video['object_name'],
                expires=timedelta(hours=1)
            )
            
            return url
            
        except Exception as e:
            raise Exception(f"Failed to generate download URL: {str(e)}")
    
    def cleanup_expired_videos(self):
        """Remove expired videos from storage and index"""
        try:
            query = {
                "query": {
                    "range": {
                        "expiry_date": {"lt": datetime.now().isoformat()}
                    }
                }
            }
            
            # Find expired videos
            result = self.es.search(index='video_downloads', body=query, size=1000)
            
            for hit in result['hits']['hits']:
                video = hit['_source']
                
                # Remove from MinIO
                try:
                    self.minio_client.remove_object(Config.MINIO_BUCKET, video['object_name'])
                except:
                    pass
                
                # Remove from Elasticsearch
                self.es.delete(index='video_downloads', id=hit['_id'])
            
            return len(result['hits']['hits'])
            
        except Exception as e:
            print(f"Cleanup error: {e}")
            return 0