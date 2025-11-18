db = db.getSiblingDB('moviedb');

db.movies.insertMany([
  { name: "Mobarak", movie: "Inception" },
  { name: "Anjana", movie: "The Harry Potter" }
]);

print("✅ Sample data inserted!");
