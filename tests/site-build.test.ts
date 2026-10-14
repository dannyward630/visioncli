import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

test(
  "site builder only shows dnf instructions when an RPM repository exists",
  { skip: process.platform === "win32" },
  () => {
    const result = spawnSync("sh", [join(root, "packaging/site/test-build.sh")], {
      cwd: root,
      encoding: "utf8",
    });
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  },
);
