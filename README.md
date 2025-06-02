# YouTube Video Downloader

A modern, full-featured YouTube video downloader with user authentication, cloud storage, and advanced search capabilities.

## Features

- 🎥 **YouTube Video Downloads**: Download videos in multiple formats and qualities
- 👤 **User Authentication**: Secure registration and login system
- ☁️ **Cloud Storage**: Videos stored in MinIO object storage
- 🔍 **Advanced Search**: Elasticsearch-powered metadata search
- 📱 **Responsive Design**: Works on desktop, tablet, and mobile
- 📊 **Analytics**: Google Analytics integration for usage tracking
- ⏰ **30-Day Storage**: Downloaded videos available for 30 days
- 🚀 **High Performance**: Redis caching and optimized architecture

## Tech Stack

- **Backend**: Flask (Python)
- **Database**: PostgreSQL
- **Search**: Elasticsearch
- **Storage**: MinIO
- **Cache**: Redis
- **Frontend**: Bootstrap 5, HTML5, JavaScript
- **Video Processing**: yt-dlp

## Project Structure

```
youtube-downloader/
├── app.py                 # Main Flask application
├── config.py             # Configuration settings
├── utils.py              # Template filters and utilities
├── requirements.txt      # Python dependencies
├── .env                  # Environment variables
├── services/
│   └── ytdlp_service.py  # Video download service
└── templates/
    ├── base.html         # Base template
    ├── index.html        # Home page
    ├── login.html        # Login page
    ├── register.html     # Registration page
    └── dashboard.html    # User dashboard
```

## Installation

### Prerequisites

- Python 3.8+
- PostgreSQL
- Redis
- Elasticsearch
- MinIO

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd youtube-downloader
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Start required services**
   
   **PostgreSQL**: Install and start PostgreSQL, create database
   ```sql
   CREATE DATABASE ytdl_app;
   ```
   
   **Redis**: Install and start Redis server
   ```bash
   redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
  
  elasticsearch:
    image: elasticsearch:8.12.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
  
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_data:/data

volumes:
  postgres_data:
  redis_data:
  elasticsearch_data:
  minio_data:
```

## API Documentation

### Authentication Required Endpoints

All API endpoints require user authentication via session cookies.

#### GET /api/video-info
Get video metadata without downloading.

**Request:**
```json
{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID"
}
```

**Response:**
```json
{
  "title": "Video Title",
  "duration": 300,
  "uploader": "Channel Name",
  "upload_date": "20240101",
  "description": "Video description",
  "thumbnail": "https://...",
  "view_count": 1000000,
  "formats": [...]
}
```

#### POST /api/download
Download a video.

**Request:**
```json
{
  "url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "format_id": "optional_format_id"
}
```

**Response:**
```json
{
  "video_id": "uuid",
  "title": "Video Title",
  "file_name": "video.mp4",
  "file_size": 50000000,
  "download_url": "/download/uuid"
}
```

#### GET /download/{video_id}
Generate presigned download URL and redirect.

#### DELETE /api/delete/{video_id}
Delete a user's video.

#### GET /api/cleanup
Admin endpoint to cleanup expired videos.

## Security Considerations

### Data Privacy
- User passwords are hashed using Werkzeug's security functions
- Session-based authentication
- Videos are isolated per user
- Automatic cleanup of expired content

### Input Validation
- YouTube URL validation
- File size limits
- User input sanitization
- SQL injection prevention via parameterized queries

### Infrastructure Security
- Use environment variables for secrets
- Enable SSL/TLS in production
- Secure MinIO and Elasticsearch endpoints
- Regular security updates

## Performance Optimization

### Caching Strategy
- Redis for session storage and temporary data
- Browser caching for static assets
- CDN for global content delivery

### Database Optimization
- Indexed queries in Elasticsearch
- Connection pooling for PostgreSQL
- Efficient pagination

### Video Processing
- Asynchronous download processing
- Quality-based format selection
- Optimized storage in MinIO

## Monitoring and Maintenance

### Logging
- Application logs via Flask logging
- Error tracking and monitoring
- User activity analytics via Google Analytics

### Maintenance Tasks
- Regular cleanup of expired videos
- Database maintenance and backups
- Storage usage monitoring

### Health Checks
```python
# Add to app.py
@app.route('/health')
def health_check():
    return {'status': 'healthy', 'timestamp': datetime.now().isoformat()}
```

## Troubleshooting

### Common Issues

1. **Video Download Fails**
   - Check yt-dlp version
   - Verify YouTube URL format
   - Check network connectivity
   - Review video availability/restrictions

2. **Storage Issues**
   - Verify MinIO connection
   - Check storage quota
   - Ensure bucket permissions

3. **Search Not Working**
   - Verify Elasticsearch connection
   - Check index creation
   - Review mapping configuration

4. **Authentication Problems**
   - Check session configuration
   - Verify database connection
   - Review password hashing

### Debug Mode
Enable debug mode for development:
```bash
export DEBUG=True
python app.py
```

### Logs Location
- Application: stdout/stderr
- PostgreSQL: `/var/log/postgresql/`
- Elasticsearch: `/var/log/elasticsearch/`
- MinIO: stdout

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Code Style
- Follow PEP 8 for Python code
- Use meaningful variable names
- Add docstrings for functions
- Comment complex logic

### Testing
```bash
# Install test dependencies
pip install pytest pytest-flask

# Run tests
pytest
```

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Legal Notice

This tool is for educational and personal use only. Users must comply with:
- YouTube's Terms of Service
- Copyright laws in their jurisdiction
- Fair use guidelines
- Content creators' rights

The developers are not responsible for misuse of this software.

## Support

For support and questions:
- Open an issue on GitHub
- Check the troubleshooting section
- Review the documentation

## Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) for video downloading
- [Flask](https://flask.palletsprojects.com/) for the web framework
- [Bootstrap](https://getbootstrap.com/) for the UI components
- All contributors to the open-source libraries used-server
   ```
   
   **Elasticsearch**: Install and start Elasticsearch
   ```bash
   # Using Docker
   docker run -d --name elasticsearch -p 9200:9200 -e "discovery.type=single-node" elasticsearch:8.12.0
   ```
   
   **MinIO**: Install and start MinIO server
   ```bash
   # Using Docker
   docker run -d --name minio -p 9000:9000 -p 9001:9001 \
     -e "MINIO_ROOT_USER=minioadmin" \
     -e "MINIO_ROOT_PASSWORD=minioadmin" \
     minio/minio server /data --console-address ":9001"
   ```

6. **Run the application**
   ```bash
   python app.py
   ```

7. **Access the application**
   - Open http://localhost:5000 in your browser

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | Flask secret key | - |
| `DEBUG` | Debug mode | `False` |
| `POSTGRES_HOST` | PostgreSQL host | `localhost` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` |
| `POSTGRES_DB` | Database name | `ytdl_app` |
| `POSTGRES_USER` | Database user | `postgres` |
| `POSTGRES_PASSWORD` | Database password | - |
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379/0` |
| `ELASTICSEARCH_HOST` | Elasticsearch host | `localhost` |
| `ELASTICSEARCH_PORT` | Elasticsearch port | `9200` |
| `MINIO_ENDPOINT` | MinIO endpoint | `localhost:9000` |
| `MINIO_ACCESS_KEY` | MinIO access key | `minioadmin` |
| `MINIO_SECRET_KEY` | MinIO secret key | `minioadmin` |
| `MINIO_BUCKET` | MinIO bucket name | `video-downloads` |
| `GA_TRACKING_ID` | Google Analytics ID | - |
| `VIDEO_EXPIRY_DAYS` | Video retention days | `30` |
| `MAX_VIDEO_SIZE` | Max video size (MB) | `500` |

### Google Analytics Setup

1. Create a Google Analytics 4 property
2. Get your Measurement ID (format: G-XXXXXXXXXX)
3. Set the `GA_TRACKING_ID` environment variable

## Usage

### For Users

1. **Registration**: Create an account to store downloads
2. **Download Videos**: 
   - Paste YouTube URL
   - Select quality/format
   - Download and access for 30 days
3. **Manage Downloads**: View, download, and delete your videos from the dashboard

### For Developers

#### Adding New Features

1. **Services**: Add new functionality in the `services/` directory
2. **Templates**: Create new HTML templates in `templates/`
3. **Routes**: Add new Flask routes in `app.py`
4. **Configuration**: Add new config options in `config.py`

#### Database Models

The application uses raw SQL with psycopg2. To add new tables:

1. Add table creation in `init_db()` function
2. Add corresponding CRUD operations as needed

#### Video Processing

Video processing is handled by `ytdlp_service.py`. Key methods:

- `get_video_info()`: Extract video metadata
- `download_video()`: Download and store video
- `get_user_videos()`: Retrieve user's videos
- `cleanup_expired_videos()`: Remove expired content

## Deployment

### Production Deployment

1. **Use a production WSGI server**
   ```bash
   gunicorn -w 4 -b 0.0.0.0:8000 app:app
   ```

2. **Set up reverse proxy** (nginx example)
   ```nginx
   server {
       listen 80;
       server_name yourdomain.com;
       
       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

3. **Environment**
   - Set `DEBUG=False`
   - Use strong `SECRET_KEY`
   - Configure proper database credentials
   - Set up SSL/TLS

### Docker Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "5000:5000"
    environment:
      - POSTGRES_HOST=postgres
      - REDIS_URL=redis://redis:6379/0
      - ELASTICSEARCH_HOST=elasticsearch
      - MINIO_ENDPOINT=minio:9000
    depends_on:
      - postgres
      - redis
      - elasticsearch
      - minio
  
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ytdl_app
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
  