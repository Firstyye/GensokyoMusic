import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, expect, it} from "vitest";

const config = JSON.parse(
  readFileSync(resolve(__dirname, "../../firebase.json"), "utf8"),
) as {
  functions?: unknown;
  database?: {rules?: string};
  emulators?: Record<string, unknown>;
};

describe("Firebase deployment configuration", () => {
  it("uses only Spark-compatible deploy and emulator targets", () => {
    expect(config).not.toHaveProperty("functions");
    expect(config.emulators).not.toHaveProperty("functions");
    expect(config.database?.rules).toBe("database.rules.json");
    expect(config.emulators).toMatchObject({
      auth: {port: 9099},
      database: {port: 9000},
      firestore: {port: 8080},
      ui: {enabled: true},
    });
  });
});
