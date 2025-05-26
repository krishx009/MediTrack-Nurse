const mongoose = require('mongoose');

let gridfsBucket;

const initializeGridFS = (db) => {
  gridfsBucket = new mongoose.mongo.GridFSBucket(db, {
    bucketName: 'uploads'
  });
  console.log('✅ GridFS bucket initialized');
  return gridfsBucket;
};

const getGridFSBucket = () => {
  if (!gridfsBucket) {
    throw new Error('GridFS not initialized');
  }
  return gridfsBucket;
};

module.exports = {
  initializeGridFS,
  getGridFSBucket
}; 