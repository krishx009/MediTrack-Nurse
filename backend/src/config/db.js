const mongoose = require("mongoose");
const dotenv = require("dotenv");
const { initializeGridFS } = require('./gridfs');

dotenv.config();

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI);
    console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
    
    // Initialize GridFS
    initializeGridFS(conn.connection.db);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
