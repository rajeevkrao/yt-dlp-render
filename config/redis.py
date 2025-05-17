import redis
import os

from dotenv import load_dotenv
load_dotenv()

url = os.getenv("REDIS_URL")

redis_client = redis.from_url(url)
