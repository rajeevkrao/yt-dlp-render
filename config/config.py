import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Flask Configuration
    SECRET_KEY = os.getenv('SECRET_KEY', 'your-secret-key-here')
    DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'
    
    # Database Configuration (PostgreSQL)
    POSTGRES_HOST = os.getenv('POSTGRES_HOST', 'localhost')
    POSTGRES_PORT = os.getenv('POSTGRES_PORT', '5432')
    POSTGRES_DB = os.getenv('POSTGRES_DB', 'ytdl_app_dev')
    POSTGRES_USER = os.getenv('POSTGRES_USER', 'postgres')
    POSTGRES_PASSWORD = os.getenv('POSTGRES_PASSWORD', 'password')
    
    DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
    
    # Redis Configuration
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    
    # Elasticsearch Configuration
    ELASTICSEARCH_HOST = os.getenv('ELASTICSEARCH_HOST', 'localhost')
    ELASTICSEARCH_PORT = os.getenv('ELASTICSEARCH_PORT', '9200')
    ELASTICSEARCH_URL = f"http://{ELASTICSEARCH_HOST}:{ELASTICSEARCH_PORT}"
    
    # MinIO Configuration
    MINIO_ENDPOINT = os.getenv('MINIO_ENDPOINT', 'localhost:9000')
    MINIO_ACCESS_KEY = os.getenv('MINIO_ACCESS_KEY', 'minioadmin')
    MINIO_SECRET_KEY = os.getenv('MINIO_SECRET_KEY', 'minioadmin')
    MINIO_BUCKET = os.getenv('MINIO_BUCKET', 'video-downloads')
    MINIO_SECURE = os.getenv('MINIO_SECURE', 'False').lower() == 'true'
    
    # Google Analytics
    GA_TRACKING_ID = os.getenv('GA_TRACKING_ID', 'G-XXXXXXXXXX')
    
    # Application Settings
    VIDEO_EXPIRY_DAYS = int(os.getenv('VIDEO_EXPIRY_DAYS', '30'))
    MAX_VIDEO_SIZE = int(os.getenv('MAX_VIDEO_SIZE', '500'))  # MB
    ALLOWED_FORMATS = ['mp4', 'webm', 'mkv', 'avi']
    