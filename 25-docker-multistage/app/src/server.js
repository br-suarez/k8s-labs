// Minimal HTTP service. Small on purpose — the subject of this lab is the
// image around it, not the code.
const express = require("express");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3000;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, "data");

// Writing a startup marker on boot is a very common pattern (pid files, lock
// files, cache warmup) and a very common source of "works on my machine":
// it is the first thing that fails when the image runs as a non-root user but
// the directory is owned by root.
try {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(path.join(DATA_DIR, "started.txt"), new Date().toISOString());
  console.log(`startup marker written to ${DATA_DIR}`);
} catch (err) {
  console.error(`FATAL: cannot write startup marker to ${DATA_DIR}`);
  console.error(`${err.code}: ${err.message}`);
  process.exit(1);
}

const app = express();

app.get("/healthz", (_req, res) => res.status(200).send("ok"));

app.get("/", (_req, res) =>
  res.json({
    service: "checkout-api",
    uid: process.getuid ? process.getuid() : null,
    node: process.version,
  })
);

app.listen(PORT, () => console.log(`checkout-api listening on :${PORT}`));
