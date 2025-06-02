from flask import Flask, render_template, request, jsonify, redirect, url_for, session, flash
from werkzeug.security import generate_password_hash, check_password_hash
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import re
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
    
    conn.commit()
    cur.close()
    conn.close()

@app.before_first_request
def create_tables():
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
            flash('Registration failed')
            return render_template('register.html')
    
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    """User login"""
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
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
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """User logout"""
    session.clear()
    return redirect(url_for('index'))

@app.route('/dashboard')
def dashboard():
    """User dashboard"""
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    page = request.args.get('page', 1, type=int)
    try:
        videos_data = ytdlp_service.get_user_videos(session['user_id'], page=page)
        return render_template('dashboard.html', 
                             videos=videos_data['videos'],
                             pagination=videos_data,
                             ga_id=Config.GA_TRACKING_ID)
    except Exception as e:
        flash(f'Error loading videos: {str(e)}')
        return render_template('dashboard.html', videos=[], pagination={'total': 0, 'page': 1, 'pages': 1}, ga_id=Config.GA_TRACKING_ID)

@app.route('/api/video-info', methods=['POST'])
def get_video_info():
    """Get video information"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    url = data.get('url')
    
    if not url or not is_valid_url(url):
        return jsonify({'error': 'Invalid YouTube URL'}), 400
    
    try:
        info = ytdlp_service.get_video_info(url)
        return jsonify(info)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/download', methods=['POST'])
def download_video():
    """Download video"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    data = request.get_json()
    url = data.get('url')
    format_id = data.get('format_id')
    
    if not url or not is_valid_url(url):
        return jsonify({'error': 'Invalid YouTube URL'}), 400
    
    try:
        result = ytdlp_service.download_video(url, session['user_id'], format_id)
        return jsonify(result)
    except Exception as e:
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
        flash(f'Download error: {str(e)}')
        return redirect(url_for('dashboard'))

@app.route('/api/delete/<video_id>', methods=['DELETE'])
def delete_video(video_id):
    """Delete a video"""
    if 'user_id' not in session:
        return jsonify({'error': 'Not authenticated'}), 401
    
    try:
        # This would need to be implemented in the YTDLPService
        # For now, return success
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/cleanup')
def cleanup_expired():
    """Cleanup expired videos (admin endpoint)"""
    try:
        count = ytdlp_service.cleanup_expired_videos()
        return jsonify({'cleaned': count})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)