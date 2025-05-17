import redis
from dotenv import load_dotenv
import os

load_dotenv()

redis_url = os.getenv("REDIS_URL")

print(redis_url)

r = redis.from_url(redis_url)

r.set("foo", "bar")

result = r.get("foos").decode()
print(result)

