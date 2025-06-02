from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import re
import atexit
from config.config import Config
from services.ytdlp_service import YTDLPService
from utils import register_template_filters

app = Flask(__name__)
app.config.from_object(Config)

# Register template filters
register_template_filters(app)

# Initialize services
ytdlp_service = YTDLPService()

def get_db_connection():
    """Get database connection"""
    # print full url for debugging
    # print(f"Connecting to database at {Config.POSTGRES_HOST}:{Config.POSTGRES_PORT}/{Config.POSTGRES_DB}")
    return psycopg2.connect(
        host=Config.POSTGRES_HOST,
        port=Config.POSTGRES_PORT,
        database=Config.POSTGRES_DB,
        user=Config.POSTGRES_USER,
        password=Config.POSTGRES_PASSWORD,
        cursor_factory=RealDictCursor
    )

def init_db():
    """Initialize database tables"""
    conn = get_db_connection()
    cur = conn.cursor()
    
    # Users table
    cur.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            username VARCHAR(50) UNIQUE NOT NULL,
            email VARCHAR(100) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Videos table for metadata storage
    cur.execute('''
        CREATE TABLE IF NOT EXISTS videos (
            id SERIAL PRIMARY KEY,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            video_id VARCHAR(50) NOT NULL,
            title TEXT NOT NULL,
            uploader VARCHAR(255),
            duration INTEGER,
            upload_date DATE,
            view_count BIGINT,
            like_count BIGINT,
            tags TEXT[],
            description TEXT,
            thumbnail_url TEXT,
            file_path TEXT,
            file_size BIGINT,
            format_id VARCHAR(50),
            status VARCHAR(20) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            expires_at TIMESTAMP,
            minio_object_name TEXT,
            UNIQUE(user_id, video_id)
        )
    ''')
    
    # Download queue table
    cur.execute('''
        CREATE TABLE IF NOT EXISTS download_queue (
            id SERIAL PRIMARY KEY,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            url TEXT NOT NULL,
            format_id VARCHAR(50),
            status VARCHAR(20) DEFAULT 'queued',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            started_at TIMESTAMP,
            completed_at TIMESTAMP,
            error_message TEXT
        )
    ''')
    
    conn.commit()
    cur.close()
    conn.close()

# Initialize database when app starts
with app.app_context():
    init_db()

def is_valid_url(url):
    """Validate YouTube URL"""
    youtube_regex = re.compile(
        r'(https?://)?(www\.)?(youtube|youtu|youtube-nocookie)\.(com|be)/'
        r'(watch\?v=|embed/|v/|.+\?v=)?([^&=%\?]{11})'
    )
    return youtube_regex.match(url) is not None

@app.route('/')
def index():
    """Home page"""
    return render_template('index.html', ga_id=Config.GA_TRACKING_ID)

@app.route('/register', methods=['GET', 'POST'])
def register():
    """User registration"""
    if request.method == 'POST':
        username = request.form['username']
        email = request.form['email']
        password = request.form['password']
        
        if not username or not email or not password:
            flash('All fields are required')
            return render_template('register.html')
        
        # Basic validation
        if len(username) < 3 or len(username) > 50:
            flash('Username must be between 3 and 50 characters')
            return render_template('register.html')
        
        if len(password) < 6:
            flash('Password must be at least 6 characters')
            return render_template('register.html')
        
        # Email validation
        email_regex = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        if not email_regex.match(email):
            flash('Please enter a valid email address')
            return render_template('register.html')
        
        password_hash = generate_password_hash(password)
        
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                'INSERT INTO users (username, email, password_hash) VALUES (%s, %s, %s)',
                (username, email, password_hash)
            )
            conn.commit()
            cur.close()
            conn.close()
            
            flash('Registration successful! Please login.')
            return redirect(url_for('login'))
            
        except psycopg2.IntegrityError:
            flash('Username or email already exists')
            return render_template('register.html')
        except Exception as e:
            app.logger.error(f'Registration error: {str(e)}')
            flash('Registration failed')
            return render_template('register.html')
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login"""
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        if not username or not password:
            flash('Username and password are required')
            return render_template('login.html')
        
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute('SELECT * FROM users WHERE username = %s', (username,))
            user = cur.fetchone()
            cur.close()
            conn.close()
            
            if user and check_password_hash(user['password_hash'], password):
                session['user_id'] = user['id']
                session['username'] = user['username']
                return redirect(url_for('dashboard'))
            else:
                flash('Invalid credentials')
        except Exception as e:
            app.logger.error(f'Login error: {str(e)}')
            flash('Login failed')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """User logout"""
    session.clear()
    flash('You have been logged out')
    return redirect(url_for('index'))

@app.route('/dashboard')
def dashboard():
    """User dashboard"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    page = request.args.get('page', 1, type=int)
    search_query = request.args.get('search', '')
    
    try:
        videos_data = ytdlp_service.get_user_videos(
            session['user_id'], 
            page=page,
            search_query=search_query
        )
        return render_template('dashboard.html', 
                             videos=videos_data['videos'],
                             pagination=videos_data,
                             search_query=search_query,
                             ga_id=Config.GA_TRACKING_ID)
    except Exception as e:
        app.logger.error(f'Dashboard error: {str(e)}')
        flash(f'Error loading videos: {str(e)}')
        return render_template('dashboard.html', 
                             videos=[], 
                             pagination={'total': 0, 'page': 1, 'pages': 1},
                             search_query=search_query,
                             ga_id=Config.GA_TRACKING_ID)

@app.route('/api/video-info', methods=['POST'])
def get_video_info():
    """Get video information"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400
        
    url = data.get('url')
    
    if not url or not is_valid_url(url):
        return jsonify({'error': 'Invalid YouTube URL'}), 400
    
    try:
        info = ytdlp_service.get_video_info(url)
        return jsonify(info)
    except Exception as e:
        app.logger.error(f'Video info error: {str(e)}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/download', methods=['POST'])
def download_video():
    """Download video"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400
        
    url = data.get('url')
    format_id = data.get('format_id')
    
    if not url or not is_valid_url(url):
        return jsonify({'error': 'Invalid YouTube URL'}), 400
    
    try:
        info = ytdlp_service.get_video_info(url)
        available_format_ids = [f['format_id'] for f in info.get('formats', [])]
        if format_id not in available_format_ids:
            return jsonify({
                'error': 'Requested format is not available',
                'available_formats': available_format_ids
            }), 400
        
        result = ytdlp_service.download_video(url, session['user_id'], format_id)
        return jsonify(result)
    except Exception as e:
        app.logger.error(f'Download error: {str(e)}')
        return jsonify({'error': str(e)}), 500

@app.route('/download/<video_id>')
def download_file(video_id):
    """Generate download URL"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    try:
        download_url = ytdlp_service.get_download_url(video_id, session['user_id'])
        return redirect(download_url)
    except Exception as e:
        app.logger.error(f'File download error: {str(e)}')
        flash(f'Download error: {str(e)}')
        return redirect(url_for('dashboard'))

@app.route('/api/delete/<video_id>', methods=['DELETE'])
def delete_video(video_id):
    """Delete a video"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    try:
        result = ytdlp_service.delete_video(video_id, session['user_id'])
        return jsonify(result)
    except Exception as e:
        app.logger.error(f'Delete error: {str(e)}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/cleanup')
def cleanup_expired():
    """Cleanup expired videos (admin endpoint)"""
    # Add basic authentication check for admin functions
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    try:
        count = ytdlp_service.cleanup_expired_videos()
        return jsonify({'cleaned': count})
    except Exception as e:
        app.logger.error(f'Cleanup error: {str(e)}')
        return jsonify({'error': str(e)}), 500

@app.route('/api/status')
def status():
    """API status endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })

@app.errorhandler(404)
def not_found(error):
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(error):
    return render_template('500.html'), 500

# Register cleanup function to run on app shutdown
@atexit.register
def cleanup_on_exit():
    """Cleanup function called when app shuts down"""
    try:
        ytdlp_service.cleanup_expired_videos()
    except Exception as e:
        app.logger.error(f'Cleanup on exit error: {str(e)}')

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)