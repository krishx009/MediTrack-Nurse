const express = require("express");
const { addVisit } = require("../controllers/visitController");

const router = express.Router();

router.post("/add", addVisit);

module.exports = router;
