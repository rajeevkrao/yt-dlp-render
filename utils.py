from datetime import datetime
from flask import current_app

def format_duration(seconds):
    """Format duration in seconds to HH:MM:SS or MM:SS"""
    if not seconds:
        return "0:00"
    
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    
    if hours > 0:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"

def format_date(date_string):
    """Format ISO date string to readable format"""
    try:
        if isinstance(date_string, str):
            date_obj = datetime.fromisoformat(date_string.replace('Z', '+00:00'))
        else:
            date_obj = date_string
        return date_obj.strftime("%b %d, %Y")
    except:
        return "Unknown"

def format_size(size_bytes):
    """Format file size in bytes to human readable format"""
    if not size_bytes:
        return "0 B"
    
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} TB"

def days_until_expiry(expiry_date_string):
    """Calculate days until expiry"""
    try:
        if isinstance(expiry_date_string, str):
            expiry_date = datetime.fromisoformat(expiry_date_string.replace('Z', '+00:00'))
        else:
            expiry_date = expiry_date_string
        
        now = datetime.now()
        if expiry_date.tzinfo:
            now = now.replace(tzinfo=expiry_date.tzinfo)
        
        delta = expiry_date - now
        return max(0, delta.days)
    except:
        return 0

def register_template_filters(app):
    """Register custom template filters with Flask app"""
    app.jinja_env.filters['format_duration'] = format_duration
    app.jinja_env.filters['format_date'] = format_date
    app.jinja_env.filters['format_size'] = format_size
    app.jinja_env.filters['days_until_expiry'] = days_until_expiry