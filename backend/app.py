from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
import os

app = Flask(__name__)
CORS(app)

# MongoDB connection
mongo_uri = os.getenv('MONGO_URI', 'mongodb://mongodb:27017/moviedb')
client = MongoClient(mongo_uri)
db = client.moviedb
movies_collection = db.movies

@app.route('/api/movies', methods=['GET'])
def get_movies():
    movies = list(movies_collection.find({}, {'_id': 0}))
    return jsonify(movies)

@app.route('/api/movies', methods=['POST'])
def add_movie():
    data = request.get_json()
    if not data or 'name' not in data or 'movie' not in data:
        return jsonify({'error': 'Name and movie are required'}), 400
    
    movies_collection.insert_one(data)
    return jsonify({'message': 'Movie added successfully'}), 201

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)