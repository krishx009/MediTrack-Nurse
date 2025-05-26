const { Readable } = require('stream');
const mongoose = require('mongoose');
const { getGridFSBucket } = require('../config/gridfs');

const streamToGridFS = (fileBuffer, options) => {
  return new Promise((resolve, reject) => {
    const bucket = getGridFSBucket();
    const readableStream = new Readable();
    readableStream.push(fileBuffer);
    readableStream.push(null);

    const uploadStream = bucket.openUploadStream(options.filename, {
      contentType: options.contentType,
      metadata: options.metadata,
    });

    let fileId = uploadStream.id;

    readableStream.pipe(uploadStream);

    uploadStream.on("error", (error) => {
      reject(error);
    });

    uploadStream.on("finish", () => {
      resolve({
        _id: fileId,
        filename: options.filename,
        contentType: options.contentType,
        metadata: options.metadata,
      });
    });
  });
};

const getFileFromGridFS = async (fileId) => {
  if (!mongoose.Types.ObjectId.isValid(fileId)) {
    throw new Error('Invalid file ID');
  }
  const bucket = getGridFSBucket();
  const file = await bucket.find({ _id: new mongoose.Types.ObjectId(fileId) }).next();
  if (!file) {
    throw new Error('File not found');
  }
  return file;
};

const streamFileFromGridFS = (fileId, res) => {
  if (!mongoose.Types.ObjectId.isValid(fileId)) {
    throw new Error('Invalid file ID');
  }
  const bucket = getGridFSBucket();
  const downloadStream = bucket.openDownloadStream(new mongoose.Types.ObjectId(fileId));
  downloadStream.pipe(res);
};

const deleteFileFromGridFS = async (fileId) => {
  if (!mongoose.Types.ObjectId.isValid(fileId)) {
    throw new Error('Invalid file ID');
  }
  const bucket = getGridFSBucket();
  await bucket.delete(new mongoose.Types.ObjectId(fileId));
};

module.exports = {
  streamToGridFS,
  getFileFromGridFS,
  streamFileFromGridFS,
  deleteFileFromGridFS
}; 